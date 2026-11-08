module Analytics
  # Everything the Pro analytics page shows for a window, the numbers drawn
  # and the pages in view, on the chart filter every chart page shares: a row
  # per page, the builder's own and one per project, as the public page
  # orders and colours them, each counting Openstage's own four numbers and a
  # project also its commits, MRR, paying customers, site visits and site
  # visitors, those its builder hides from visitors too; what
  # Progress::DrawService makes of their counts, each number's total and change
  # for the pages in view and the one chart of the numbers drawn; and the panels
  # of those pages (GatherPagesService) and of the builder's websites
  # (GatherWebsitesService).
  class ReportService < ApplicationService
    # It opens on commits alone, over the window every chart page opens on.
    DEFAULT_SHOW = %w[commits].freeze
    TOP = 6
    TOP_COUNTRIES = 5
    # The last row of a ranked panel: everything its list leaves out, so its
    # rows add up to its total.
    OTHER = "Other".freeze

    # range: a Progress::Window range, nil for the default; show: the numbers
    # asked for, by key in line order; pages: the pages in view, by key, none
    # for all of them.
    attr_accessor :user, :range, :show, :pages
    # totals_window: the Window the totals cover; rows: a Progress::Row per page, in
    # the pages' fixed order; drawing: the DrawService of the totals and the chart.
    # websites: the GatherWebsitesService of the website panels; on_pages: the
    # GatherPagesService of the panels of their pages.
    attr_reader :totals_window, :rows, :counts, :drawing, :websites, :on_pages

    delegate :totals, :drawn, :default_drawn, :window, :chart, :earliest, to: :drawing
    delegate :sources, :countries, :links, :badges, to: :on_pages

    validates :user, presence: true

    def selected
      rows.select(&:on)
    end

    # The pages in view, by key; none for all of them.
    def selected_keys
      rows.all?(&:on) ? [] : selected.map(&:key)
    end

    # The table's numbers: every one a page shows.
    def columns
      drawing.shown
    end

    # A row's cells under the table's numbers. Analytics only reads them:
    # what visitors see is picked on the dashboard.
    def cells(row)
      drawing.cells(row, columns)
    end

    # The first project in view, whose site visits the website panels offer
    # to set up while none of the projects in view counts them; nil when only
    # the builder's stage is.
    def setup_row
      selected.find(&:repo)
    end

    private

    def execute
      @totals_window = Progress::Window.new(range: range, today: today, first_activity: nil)
      return unless count

      @rows = page_rows
      return unless draw

      read_pages
      read_websites
    end

    def today
      @today ||= Time.current.in_time_zone(user.zone).to_date
    end

    # The window before the range too, for the changes; every day for all time.
    def count
      start = FindStartService.new(user: user)
      return unless run(start)

      service = CountService.new(user: user, from: totals_window.span_before&.first)
      @counts = Progress::Counts.new(days: service.counts, firsts: start.firsts, through: service.through, currency: service.currency) if run(service)
    end

    # The builder's page first, then each project, as far as the pages asked
    # for keep them in view (Progress::Filter.in_view).
    def page_rows
      synced = user.github_repos.by_full_name(projects.map(&:repo))
      all = [ [ CountService::PAGE, "Your stage", nil ] ] + projects.map { |project| [ project.repo, project.name, project.rank ] }
      in_view = Progress::Filter.in_view(pages, all.select { |_key, _name, rank| ProgressChart::Palette.colored?(rank) }.map(&:first))
      all.map { |key, name, rank| row(key, name, rank, synced[key], in_view.empty? || in_view.include?(key)) }
    end

    def projects
      @projects ||= Progress::Projects.new(user.entries.publicly_counted.without_tooling_noise).all
    end

    # A page counts a number once it has counted it on any day, and shows every
    # one it counts: this page is its builder's alone, and a project's switches
    # only say what visitors see.
    def row(key, name, rank, repo, on)
      counted = Progress::Numbers::ALL.map(&:key).select { |number| counts.first_day(number, [ key ]) }
      Progress::Row.new(key: key, name: name, rank: rank, color_class: ProgressChart::Palette.project_class(rank), repo: repo, on: on,
                        counted: counted, shown: counted)
    end

    def draw
      service = Progress::DrawService.new(rows: rows, counts: counts, totals_window: totals_window, show: show, default_show: DEFAULT_SHOW, per: "page")
      @drawing = service if run(service)
    end

    def read_pages
      split = Split.new(user, first: totals_window.span&.first, last: totals_window.last)
      service = GatherPagesService.new(user: user, pages: selected, split: split)
      @on_pages = service if run(service)
    end

    # Every project of the builder's while all are in view, those with no row
    # too, else the projects in view; their stage is not a website.
    def read_websites
      repos = selected_keys.empty? ? user.github_repos : selected.filter_map(&:repo)
      service = GatherWebsitesService.new(user: user, repos: repos, days: totals_window.span)
      @websites = service if run(service)
    end

    def run(service)
      service.call
      absorb_errors(service)
    end
  end
end
