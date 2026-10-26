module SiteVisits
  # The site visits a chart draws beside the commits of its section
  # (Progress::ComposeService): the projects in view whose visits it shows,
  # their visits on their own (TallyService), and their visits on the
  # section's own points, to compare with its commits. A public page shows a
  # project's visits where its builder shows them (GithubRepo#site_visits_public?);
  # the builder's dashboard, where they picked them for it.
  class GatherService < ApplicationService
    # dashboard: the builder's own chart, rather than a public page's.
    attr_accessor :user, :section, :dashboard
    # repos: the projects drawn, none for nothing to draw; tally: their
    # visits alone; series: {repo's full name => visits per point of the section}.
    attr_reader :repos, :tally, :series

    validates :user, :section, presence: true

    def any?
      repos.present?
    end

    private

    def execute
      @repos = drawn_repos
      return if repos.empty?

      @tally = TallyService.new(repos: repos, range: section.labels.range)
      tally.call
      return unless absorb_errors(tally)

      @series = section_series
    end

    def drawn_repos
      in_view = (section.selected.presence || section.tally.projects.all).map(&:repo)
      counted = user.github_repos.where(full_name: in_view).where.not(site_first_visit_at: nil).to_a
      dashboard ? counted.select { |repo| repo.dashboard_numbers.include?("visits") } : counted.select(&:site_visits_public?)
    end

    # The 30-day view's points are 7-day averages, as its commits are.
    def section_series
      period = section.tally.period
      average = section.labels.range == "30d"
      from = period.buckets.first.first - (ProgressChart::Trend::AVERAGE - 1)
      days = SiteVisitDay.where(github_repo_id: repos.map(&:id), day: from..period.last_day).group(:github_repo_id, :day).sum(:visits)
      repos.to_h do |repo|
        [ repo.full_name, period.buckets.map { |bucket| average ? averaged(days, repo.id, bucket.first) : summed(days, repo.id, bucket) } ]
      end
    end

    def averaged(days, id, day)
      (0...ProgressChart::Trend::AVERAGE).sum { |back| days.fetch([ id, day - back ], 0) } / ProgressChart::Trend::AVERAGE.to_f
    end

    def summed(days, id, bucket)
      (bucket.first..bucket.last).sum { |day| days.fetch([ id, day ], 0) }
    end
  end
end
