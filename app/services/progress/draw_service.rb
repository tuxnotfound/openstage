module Progress
  # What a chart filter shows from its rows and their counts over a window,
  # on every chart page: each number a row shows, with its total for the rows
  # in view, the window before's and each row's part of it; the numbers drawn
  # (those asked for, else the page's own, else the first); and the one chart
  # of them, from where the numbers drawn start for the rows in view with a
  # colour. A row past the palette has none: it counts in the totals and
  # draws no line (ProgressChart::Compare#lines).
  class DrawService < ApplicationService
    # The numbers a chart draws at once, each in its own line.
    MAX_DRAWN = 3

    # A number a row shows, with its total for the rows in view over the
    # window (nil when none of them shows it), the window before's (nil with
    # nothing to compare with), and the part of each row in view with any,
    # as [row, count].
    Total = Data.define(:number, :value, :previous, :split)
    # A row's cell under one of the table's numbers: its value over the
    # window where the table lists it (nil otherwise), the window before's
    # where visitors see it, whether they do, and on the builder's own table
    # its switch (pick) or what stands in its place (link, Row#link).
    Cell = Data.define(:number, :value, :previous, :shown, :pick, :link)

    # rows: Progress::Rows, in the page's order; counts: a Progress::Counts;
    # totals_window: the Window the totals cover. show: the numbers asked for, by key
    # in line order; default_show: the page's own. average: each point a
    # 7-day average; lone: one project's page; per: what a row is, "project"
    # or "page".
    attr_accessor :rows, :counts, :totals_window, :show, :default_show, :average, :lone, :per
    # window: the chart's points.
    attr_reader :totals, :drawn, :default_drawn, :window, :chart

    validates :counts, :totals_window, presence: true

    # A row's cells under the table's numbers (columns); manage: the
    # builder's own table, where they pick what visitors see.
    def cells(row, columns, manage: false)
      columns.map do |number|
        key = number.key
        link = (row.link(key) if manage)
        Cell.new(number: number, value: listed(number, row, manage, link), previous: (previous(number, [ row ]) if row.shows?(key)),
                 shown: row.shows?(key), pick: (row.pick(key) if manage), link: link)
      end
    end

    private

    def execute
      @totals = Numbers::ALL.filter_map { |number| total(number) if Array(rows).any? { |row| row.shows?(number.key) } }
      @default_drawn = drawable(default_show)
      @drawn = drawable(show).presence || default_drawn.presence || totals.first(1).map(&:number)
      @chart = draw
    end

    def total(number)
      shown = showing(number)
      split = shown.map { |row| [ row, value(number, row) ] }
      Total.new(number: number, value: (split.sum(&:last) if shown.any?), previous: previous(number, shown), split: split.select { |_, count| count.positive? })
    end

    def drawable(keys)
      shown = totals.map(&:number)
      Array(keys).filter_map { |key| shown.find { |number| number.key == key } }.uniq.first(MAX_DRAWN)
    end

    def draw
      first = drawn.filter_map { |number| counts.first_day(number.key, showing(number).select(&:color_class).map(&:key)) }.min
      @window = Window.new(range: totals_window.range, today: totals_window.today, first_activity: first)
      lines = drawn.flat_map { |number| showing(number).map { |row| line(number, row) } }
      ProgressChart::Compare.new(window: window, lines: lines, numbers: drawn, average: average.present?, lone: lone.present?, per: per || "project")
    end

    def showing(number)
      Array(rows).select { |row| row.on && row.shows?(number.key) }
    end

    def line(number, row)
      ProgressChart::Compare::Line.new(repo: row.key, name: row.name, rank: row.rank, color_class: row.color_class, number: number,
                                       values: counts.per_point(number.key, row.key, window.buckets, average: average.present?),
                                       total: counts.sum(number.key, row.key, window.days))
    end

    # A row's count of a number over the window.
    def value(number, row)
      counts.sum(number.key, row.key, totals_window.span)
    end

    # Its value where the table lists it; beside a link (Paused, Set up),
    # only when the window has any.
    def listed(number, row, manage, link)
      return unless row.lists?(number.key, manage)

      count = value(number, row)
      count if link.nil? || count.positive?
    end

    # Some rows' count of a number over the window before, only while it
    # counted before the window began; nil otherwise.
    def previous(number, some)
      before = totals_window.span_before
      first = counts.first_day(number.key, some.map(&:key))
      return unless before && first && first < totals_window.span.first

      some.sum { |row| counts.sum(number.key, row.key, before) }
    end
  end
end
