module Progress
  # What a page's chart filter shows for a window, the numbers asked for and
  # the projects in view: the page's section (ComposeService), a row per
  # project for the table under the chart, and what DrawService makes of
  # their counts: each number the projects show visitors, with its total for
  # the projects in view and their part of it, and the one chart of the
  # numbers drawn. The builder's own view (the dashboard) also lists in its
  # rows the numbers their visitors do not see, and the projects hidden from
  # their page; its chart draws what visitors see.
  class ChartService < ApplicationService
    # Every chart page opens on these, as far as its projects show them.
    DEFAULT_SHOW = %w[commits visits].freeze

    # repos: the projects in view, none for all of them; show: the numbers
    # asked for, by key in line order, none for the default. reveal: a repo
    # the builder hid, shown anyway (Entry.on_page). lone: a project's page,
    # whose one project in view is all it shows. builder: the builder's own view.
    attr_accessor :user, :range, :repos, :show, :reveal, :lone, :builder
    # rows (Progress::Rows) and off_page (GithubRepos) are the table's;
    # columns, its numbers; drawing: the DrawService of the totals and the chart.
    attr_reader :section, :rows, :off_page, :columns, :counts, :drawing

    delegate :totals, :drawn, :default_drawn, :window, :chart, :value, :previous, to: :drawing

    validates :user, presence: true

    # The window the totals cover.
    def period
      section.tally.period
    end

    # The projects in view, by key; none for all of them.
    def selected_keys
      section.filtered? ? section.selected.map(&:repo) : []
    end

    private

    def execute
      return unless compose

      list
      return unless count && draw

      @columns = builder ? builder_columns : totals.map(&:number)
    end

    # A list that names no project of theirs, or every one, shows them all,
    # as no list does; a project's page keeps its one project.
    def compose
      service = composed(repos)
      service = composed([]) if service && Array(repos).any? && (service.section.selected.empty? || (!lone && every?(service.section)))
      @section = service&.section
    end

    def composed(picked)
      service = ComposeService.new(user: user, range: range, repos: Array(picked), rolling: true, reveal: reveal)
      service if run(service)
    end

    def every?(section)
      section.selected.size == section.tally.projects.all.size
    end

    # The page's projects, and on the builder's own view the ones hidden from their page.
    def list
      projects = lone ? section.selected : section.tally.projects.all
      synced = user.github_repos.where(full_name: projects.map(&:repo)).index_by(&:full_name)
      @rows = projects.map { |project| row(project, synced[project.repo]) }
      @off_page = builder ? user.github_repos.with_entries.where(included: false).order(:name).to_a : []
    end

    def row(project, repo)
      counted = [ ("commits" if project.commits.positive?), ("visits" if repo&.site_first_visit_at) ].compact
      Row.new(key: project.repo, name: project.name, rank: project.rank, repo: repo, on: !section.filtered? || section.selected.include?(project),
              counted: counted, shown: counted.select { |key| repo.nil? || repo.public_number?(key) })
    end

    def count
      service = CountService.new(user: user, zone: section.tally.zone, reveal: reveal, from: count_from,
                                 commit_repos: rows.select { |row| row.counts?("commits") }.map(&:key),
                                 visit_repos: rows.select { |row| builder ? row.counts?("visits") : row.shows?("visits") }.map(&:repo))
      @counts = service.counts if run(service)
    end

    # The window before the range, and the six days before it that the
    # 30-day view's first average reads; every day for all time.
    def count_from
      [ period.span_before&.first, period.span && (period.span.first - (ProgressChart::Trend::AVERAGE - 1)) ].compact.min
    end

    # Each number its projects show visitors, the numbers drawn and the chart.
    def draw
      service = DrawService.new(rows: rows, counts: counts, period: period, show: show, default_show: DEFAULT_SHOW,
                                average: period.range == "30d", lone: lone, per: "project")
      @drawing = service if run(service)
    end

    # Every number a project here could show, so one none shows yet can be
    # switched on, and site visits, so a project can set them up.
    def builder_columns
      Numbers::ALL.select { |number| number.picked && (number.key == "visits" || rows.any? { |row| row.counts?(number.key) }) }
    end

    def run(service)
      service.call
      absorb_errors(service)
    end
  end
end
