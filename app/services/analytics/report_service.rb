module Analytics
  # Everything a tab of the analytics page (Tab) shows for a window, the
  # numbers drawn and the pages in view, on the chart filter every chart
  # page shares: a row per page, the builder's stage on the tabs that list
  # it, then each project, as the public page orders and colours them, each
  # counting the tab's numbers, those its builder hides from visitors too;
  # what Progress::DrawService makes of their counts, in the tab's order:
  # each number's total and change for the pages in view, and the one chart
  # of the numbers drawn, with what shipped and was published marked on it;
  # and the lists under it, of the builder's websites (GatherWebsitesService)
  # or of their pages on Openstage (GatherPagesService), on the tab that
  # shows them alone. Free reads only Tab#numbers_for, and the site visits of
  # its one project (SiteVisits::Slot).
  class ReportService < ApplicationService
    # A list's rows, before Other.
    TOP = 8
    # A list's last row: everything it leaves out, so its rows add up to
    # its total.
    OTHER = "Other".freeze

    # tab: an Analytics::Tab; range: a Progress::Window range, nil for the
    # default; show: the numbers asked for, by key in line order; pages: the
    # pages in view, by key, none for all of them.
    attr_accessor :user, :tab, :range, :show, :pages
    # totals_window: the Window the totals cover; rows: a Progress::Row per page, in
    # the pages' fixed order; drawing: the DrawService of the totals and the chart.
    # websites: the GatherWebsitesService of the website lists, on Site visits
    # alone; on_pages: the GatherPagesService of the lists of their pages, on
    # Openstage views alone.
    attr_reader :totals_window, :rows, :counts, :drawing, :websites, :on_pages

    delegate :totals, :drawn, :default_drawn, :window, :chart, :earliest, to: :drawing
    delegate :sources, :countries, :links, :badges, to: :on_pages

    validates :user, :tab, presence: true

    def selected
      rows.select(&:on)
    end

    # The pages in view, by key; none while every one with a box is.
    def selected_keys
      rows.select(&:boxed?).all?(&:on) ? [] : selected.map(&:key)
    end

    # The tab's numbers this builder reads, in its order.
    def numbers
      @numbers ||= tab.numbers_for(user).map { |key| Progress::Numbers.find(key) }
    end

    # The table's numbers: the tab's that a row shows, and site visits
    # whatever, on the tabs that list them, so Set up has a place.
    def columns
      @columns ||= numbers.select { |number| drawing.shown.include?(number) || number.key == "visits" }
    end

    # The tiles' numbers, each with its Total: the tab's that a row shows.
    def tiles
      numbers.select { |number| tab.tiles.include?(number.key) && drawing.shown.include?(number) }
             .map { |number| totals.find { |total| total.number == number } || drawing.total(number) }
    end

    # A row's cells under the table's numbers, with Set up and Paused where
    # site visits do not count. Analytics only reads them: what visitors see
    # is picked on the dashboard.
    def cells(row)
      drawing.cells(row, columns, links: true)
    end

    # What a row is: a page while the builder's stage is one, else a project.
    def per
      tab.stage?(user) ? "page" : "project"
    end

    # The project whose site visits the website lists offer to set up while
    # none of the projects in view counts them: on Free the one it counts,
    # else the first in view, or the first that counts none, which is never
    # in view; nil when none has a repo.
    def setup_row
      held = slot.repo
      return rows.find { |row| row.repo == held } if held && !user.pro?

      selected.find(&:repo) || rows.find { |row| row.idle && row.repo }
    end

    private

    def execute
      @totals_window = Progress::Window.new(range: range, today: today, first_activity: nil)
      return unless count

      @rows = page_rows
      return unless draw

      read_websites if tab.lists == :websites
      read_pages if tab.lists == :pages
    end

    def today
      @today ||= Time.current.in_time_zone(user.zone).to_date
    end

    # The window before the range too, for the changes; every day for all time.
    def count
      keys = numbers.map(&:key)
      start = FindStartService.new(user: user, numbers: keys, sites: sites)
      return unless run(start)

      service = CountService.new(user: user, from: totals_window.span_before&.first, numbers: keys, sites: sites)
      @counts = Progress::Counts.new(days: service.counts, firsts: start.firsts, through: service.through, currency: service.currency) if run(service)
    end

    # The projects whose site visits count: every one on Pro, Free's one.
    def sites
      Array(slot.repo&.id) unless user.pro?
    end

    def slot
      @slot ||= SiteVisits::Slot.new(user)
    end

    def page_rows
      PageRows.new(user: user, tab: tab, counts: counts, pages: pages, slot: slot).all
    end

    def draw
      service = Progress::DrawService.new(rows: rows, counts: counts, totals_window: totals_window, show: show, default_show: tab.opens_on, per: per,
                                          builder: true, numbers: numbers, items: highlights)
      @drawing = service if run(service)
    end

    def highlights
      Highlights.new(user, first: totals_window.span&.first, last: totals_window.last, rows: rows.select(&:drawn?)).all
    end

    # Every project of the builder's while all are in view, those with no row
    # too, else the projects in view; their stage is not a website. Free's
    # one alone.
    def read_websites
      repos = selected_keys.empty? ? user.github_repos : user.github_repos.where(id: selected.filter_map { |row| row.repo&.id })
      repos = repos.where(id: sites) if sites
      service = GatherWebsitesService.new(user: user, repos: repos, days: totals_window.span)
      @websites = service if run(service)
    end

    def read_pages
      split = Split.new(user, first: totals_window.span&.first, last: totals_window.last)
      service = GatherPagesService.new(user: user, pages: selected, split: split)
      @on_pages = service if run(service)
    end

    def run(service)
      service.call
      absorb_errors(service)
    end
  end
end
