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
    # A builder's page, a project's page and the dashboard open on these, as
    # far as their projects show them; analytics opens on its own.
    DEFAULT_SHOW = %w[commits visits].freeze

    # repos: the projects in view, none for all of them; show: the numbers
    # asked for, by key in line order, none for the default. reveal: a repo
    # the builder hid, shown anyway (Entry.on_page). lone: a project's page,
    # whose one project in view is all it shows. builder: the builder's own view.
    attr_accessor :user, :range, :repos, :show, :reveal, :lone, :builder
    # rows (Progress::Rows) and off_page (GithubRepos) are the table's;
    # columns, its numbers; drawing: the DrawService of the totals and the chart.
    attr_reader :section, :rows, :off_page, :columns, :counts, :drawing

    delegate :totals, :drawn, :default_drawn, :window, :chart, to: :drawing

    validates :user, presence: true

    # The window the totals cover.
    def totals_window
      section.tally.period
    end

    # The projects in view, by key; none for all of them.
    def selected_keys
      section.filtered? ? section.selected.map(&:repo) : []
    end

    # A row's cells under the table's numbers, as the builder's own view
    # manages what visitors see.
    def cells(row)
      drawing.cells(row, columns, manage: builder.present?)
    end

    private

    def execute
      return unless compose

      list
      return unless count && draw

      @columns = builder ? builder_columns : totals.map(&:number)
    end

    # The projects a list names, as far as they stay in view (in_view).
    def compose
      service = composed(repos)
      return unless service

      named = in_view(service.section)
      @section = named.sort == Array(repos).uniq.sort ? service.section : composed(named)&.section
    end

    def composed(keys)
      service = ComposeService.new(user: user, range: range, repos: Array(keys), rolling: true, reveal: reveal, counting: counting)
      service if run(service)
    end

    # What the table and the chart count besides the section's period, read
    # with the section's commits: every project's from count_from on, or on
    # a project's page its own.
    def counting
      TallyService::Counting.new(from: count_from, repos: (Array(repos) if lone))
    end

    # The window before the range, and the six days before it that the
    # 30-day view's first average reads; every day for all time. Known before
    # the section is, as no window's span hangs on where the work began.
    def count_from
      return @count_from if defined?(@count_from)

      window = Window.new(range: range, today: Time.current.in_time_zone(user.zone).to_date, first_activity: nil)
      @count_from = [ window.span_before&.first, window.span && (window.span.first - (Window::AVERAGE - 1)) ].compact.min
    end

    # The projects a list keeps in view (Filter.in_view); a project's page
    # keeps its one project.
    def in_view(section)
      return section.selected.map(&:repo) if lone && section.selected.any?

      colored = section.tally.projects.all.select { |project| ProgressChart::Palette.colored?(project.rank) }
      Filter.in_view(section.selected.map(&:repo), colored.map(&:repo))
    end

    # The page's projects, and on the builder's own view the ones hidden from
    # their page. Which project Free counts site visits for is read once.
    def list
      projects = lone ? section.selected : section.tally.projects.all
      synced = user.github_repos.by_full_name(projects.map(&:repo))
      slot = SiteVisits::Slot.new(user)
      @rows = projects.map { |project| row(project, synced[project.repo], slot) }
      @off_page = builder ? user.github_repos.with_entries.where(included: false).order(:name).to_a : []
    end

    def row(project, repo, slot)
      counted = [ ("commits" if project.commits.positive?), ("visits" if repo&.site_first_visit_at) ].compact
      Row.new(key: project.repo, name: project.name, rank: project.rank, color_class: color_class(project), repo: repo,
              on: !section.filtered? || section.selected.include?(project), counted: counted,
              shown: counted.select { |key| repo.nil? || repo.public_number?(key, slot: slot) }, site: (slot.state(repo) if repo))
    end

    # A project's colour by rank. Past the palette it has none, so no box
    # and no line, except on its own page, where it stands alone.
    def color_class(project)
      lone ? ProgressChart::Palette.alone_class(project.rank) : ProgressChart::Palette.project_class(project.rank)
    end

    # The commits counted come from the section's tally and its projects,
    # which read them already.
    def count
      tally = section.tally
      service = CountService.new(user: user, from: count_from, commit_days: tally.commit_days, first_commits: tally.projects.first_commits,
                                 commit_repos: rows.select { |row| row.counts?("commits") }.map(&:key),
                                 visit_repos: rows.select { |row| builder ? row.counts?("visits") : row.shows?("visits") }.map(&:repo))
      @counts = service.counts if run(service)
    end

    # Each number its projects show visitors, the numbers drawn and the chart.
    def draw
      service = DrawService.new(rows: rows, counts: counts, totals_window: totals_window, show: show, default_show: DEFAULT_SHOW,
                                average: totals_window.range == "30d", lone: lone, per: "project")
      @drawing = service if run(service)
    end

    # Every number a project here could show, so one none shows yet can be
    # switched on, and site visits, so a project can set them up.
    def builder_columns
      Numbers::ALL.select { |number| number.pickable && (number.key == "visits" || rows.any? { |row| row.counts?(number.key) }) }
    end

    def run(service)
      service.call
      absorb_errors(service)
    end
  end
end
