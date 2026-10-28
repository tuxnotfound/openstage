module Progress
  # What a page's chart filter shows for a window, the numbers asked for and
  # the projects in view: the page's section (ComposeService), each number
  # its projects show visitors with its total for the projects in view and
  # their part of it, a row per project for the table under the chart, and
  # the one chart of the numbers drawn. The builder's own view (the
  # dashboard) also lists in its rows the numbers their visitors do not see,
  # and the projects hidden from their page; its chart draws what visitors see.
  class ChartService < ApplicationService
    # The numbers a chart draws at once, each in its own line.
    MAX_DRAWN = 3
    # Every chart page opens on these, as far as its projects show them.
    DEFAULT_SHOW = %w[commits visits].freeze

    # A project on the page: its repo (nil with none synced), whether it is
    # in view, and the numbers it counts and the ones its visitors see, by key.
    Row = Data.define(:project, :repo, :on, :counted, :shown) do
      delegate :name, :rank, to: :project

      def key
        project.repo
      end

      def counts?(number)
        counted.include?(number)
      end

      def shows?(number)
        shown.include?(number)
      end
    end
    # A number the page shows, with its total for the projects in view over
    # the window, the window before's (nil with nothing to compare with), and
    # the part of each project in view with any, as [row, count].
    Total = Data.define(:number, :value, :previous, :split)

    # repos: the projects in view, none for all of them; show: the numbers
    # asked for, by key in line order, none for the default. reveal: a repo
    # the builder hid, shown anyway (Entry.on_page). lone: a project's page,
    # whose one project in view is all it shows. builder: the builder's own view.
    attr_accessor :user, :range, :repos, :show, :reveal, :lone, :builder
    # rows and off_page (GithubRepos) are the table's; columns, its numbers;
    # drawn: the numbers drawn, in line order; window: the chart's points.
    attr_reader :section, :rows, :off_page, :totals, :columns, :drawn, :default_drawn, :counts, :window, :chart

    validates :user, presence: true

    # A project's count of a number over the window.
    def value(number, row)
      counts.sum(number.key, row.key, period.span)
    end

    private

    def execute
      return unless compose

      list
      return unless count

      pick
      @chart = draw
    end

    # A list that names no project of theirs shows them all, as no list does.
    def compose
      service = composed(repos)
      service = composed([]) if service && Array(repos).any? && service.section.selected.empty?
      @section = service&.section
    end

    def composed(picked)
      service = ComposeService.new(user: user, range: range, repos: Array(picked), rolling: true, reveal: reveal)
      service if run(service)
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
      shown = counted.select { |key| repo.nil? || repo.public_number?(key) }
      Row.new(project: project, repo: repo, on: !section.filtered? || section.selected.include?(project), counted: counted, shown: shown)
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

    # The numbers the page shows, the table's, and the ones drawn: those
    # asked for, else the page's own, else the first it shows.
    def pick
      @totals = Numbers::ALL.filter_map { |number| total(number) if rows.any? { |row| row.shows?(number.key) } }
      @columns = builder ? builder_columns : totals.map(&:number)
      @default_drawn = drawable(DEFAULT_SHOW)
      @drawn = drawable(show).presence || default_drawn.presence || totals.first(1).map(&:number)
    end

    def total(number)
      shown = showing(number)
      split = shown.map { |row| [ row, value(number, row) ] }
      Total.new(number: number, value: split.sum(&:last), previous: previous(number, shown), split: split.select { |_, count| count.positive? })
    end

    # Only while the number counted before the window began.
    def previous(number, shown)
      before = period.span_before
      first = counts.first_day(number.key, shown.map(&:key))
      return unless before && first && first < period.span.first

      shown.sum { |row| counts.sum(number.key, row.key, before) }
    end

    # Every number a project here could show, so one none shows yet can be
    # switched on, and site visits, so a project can set them up.
    def builder_columns
      Numbers::ALL.select { |number| number.picked && (number.key == "visits" || rows.any? { |row| row.counts?(number.key) }) }
    end

    def drawable(keys)
      shown = totals.map(&:number)
      Array(keys).filter_map { |key| shown.find { |number| number.key == key } }.uniq.first(MAX_DRAWN)
    end

    # From where the numbers drawn start, for the projects in view.
    def draw
      first = drawn.filter_map { |number| counts.first_day(number.key, showing(number).map(&:key)) }.min
      @window = Window.new(range: section.labels.range, today: period.today, first_activity: first)
      lines = drawn.flat_map { |number| showing(number).map { |row| line(number, row) } }
      ProgressChart::Compare.new(window: window, lines: lines, numbers: drawn, average: section.labels.range == "30d", lone: lone)
    end

    def showing(number)
      rows.select { |row| row.on && row.shows?(number.key) }
    end

    def line(number, row)
      ProgressChart::Compare::Line.new(repo: row.key, name: row.name, rank: row.rank, number: number,
                                       values: counts.per_point(number.key, row.key, window.buckets, average: section.labels.range == "30d"),
                                       total: counts.sum(number.key, row.key, window.days))
    end

    def period
      section.tally.period
    end

    def run(service)
      service.call
      absorb_errors(service)
    end
  end
end
