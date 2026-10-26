module Progress
  # The numbers a page's chart can draw for its section (ComposeService):
  # commits always, and the site visits of the projects in view that it
  # shows; MRR and GitHub's other numbers join here. Each comes with its total
  # in the window, the window before, and each project's share; the picked
  # ones with their chart, all on the section's points so they stack in line.
  class NumbersService < ApplicationService
    # unit: what one of it is called ("commit"); before: the window before's
    # total, nil with none to compare; by_project: {repo's full name => total};
    # chart: a ProgressChart, nil unless picked.
    Number = Data.define(:key, :label, :unit, :total, :before, :by_project, :chart)

    # picked: the numbers' keys to chart; none for all of them. builder: the
    # builder's own view, which draws every project counted, shown or not.
    attr_accessor :user, :section, :picked, :builder
    attr_reader :numbers

    validates :user, :section, presence: true

    private

    def execute
      site = SiteVisits::GatherService.new(user: user, section: section, dashboard: builder)
      site.call
      return unless absorb_errors(site)

      trend = ProgressChart::Trend.new(section)
      available = [ commits(trend), (visits(trend, site) if site.any?) ].compact
      on = Array(picked) & available.map(&:key)
      on = available.map(&:key) if on.empty?
      @numbers = available.map { |number| on.include?(number.key) ? number : number.with(chart: nil) }
    end

    def commits(trend)
      totals = section.tally.totals
      Number.new(key: "commits", label: "Commits", unit: "commit", total: totals.commits, before: section.tally.previous_totals&.commits,
                 by_project: totals.counts, chart: trend)
    end

    def visits(trend, site)
      comparison = section.tally.period.comparison
      before = SiteVisitDay.where(github_repo_id: site.repos.map(&:id), day: comparison).sum(:visits) if comparison
      chart = ProgressChart::Series.new(trend, values: site.series, projects: section.tally.projects, name: "Site visits")
      Number.new(key: "visits", label: "Site visits", unit: "visit", total: site.tally.visits, before: before,
                 by_project: site.tally.lines.transform_values(&:sum), chart: chart)
    end
  end
end
