module Progress
  # What a chart filter shows from its rows and their counts over a window,
  # on every chart page: each number a row shows, for the table; of those
  # the chart can draw (Numbers::Number#drawable?), each one's total for the
  # rows in view, the window before's and each row's part of it; the numbers
  # drawn (those asked for, else the page's own, else the first); and the
  # one chart of them, from where the numbers drawn start for the rows in
  # view with a colour, else for every row in view, with what its tooltip
  # shows beside them (Numbers.beside). A row past the palette has none: it
  # counts in the totals and draws no line (ProgressChart::Compare#lines).
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
    # shown: every number a row shows, in the pages' order, the table's;
    # totals: a Total of each the chart can draw, the toggles'; window: the
    # chart's points.
    attr_reader :shown, :totals, :drawn, :default_drawn, :window, :chart

    validates :counts, :totals_window, presence: true

    # The first day a row counted a number it shows, or the window's first
    # activity when that came earlier; nil with neither. The calendar offers
    # no day before it, and a number a row hides dates nothing.
    def earliest
      firsts = Numbers::ALL.filter_map { |number| counts.first_day(number.key, Array(rows).select { |row| row.shows?(number.key) }.map(&:key)) }
      [ totals_window.first_activity, *firsts ].compact.min
    end

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
      @shown = Numbers::ALL.select { |number| Array(rows).any? { |row| row.shows?(number.key) } }
      @totals = shown.select(&:drawable?).map { |number| total(number) }
      @default_drawn = drawable(default_show)
      @drawn = drawable(show).presence || default_drawn.presence || totals.first(1).map(&:number)
      @chart = draw
    end

    def total(number)
      in_view = showing(number)
      split = in_view.map { |row| [ row, value(number, row) ] }
      Total.new(number: number, value: (split.sum(&:last) if in_view.any?), previous: previous(number, in_view), split: split.select { |_, count| count.positive? })
    end

    # The numbers some keys name that the chart can draw, as the totals have
    # them: a number no row shows, or one that sits beside another, is left
    # out, as if never asked for.
    def drawable(keys)
      numbers = totals.map(&:number)
      Array(keys).filter_map { |key| numbers.find { |number| number.key == key } }.uniq.first(MAX_DRAWN)
    end

    def draw
      @window = Window.new(range: totals_window.range, today: totals_window.today, first_activity: first_drawn_day)
      lines = drawn.flat_map { |number| showing(number).map { |row| line(number, row) } }
      ProgressChart::Compare.new(window: window, lines: lines, beside: beside_lines, numbers: drawn, average: average.present?, lone: lone.present?,
                                 per: per || "project")
    end

    # What the tooltip shows beside each number drawn (Numbers.beside), of
    # the rows that draw its lines and show it too: a project's site
    # visitors beside its site visits, never a project's that hides them.
    def beside_lines
      drawn.flat_map do |number|
        Numbers.beside(number).flat_map { |other| showing(number).select { |row| row.shows?(other.key) }.map { |row| line(other, row) } }
      end
    end

    # Where the numbers drawn start for the rows in view with a colour, which
    # draw the lines; else for every row in view, so a chart whose counts are
    # all past the palette still spans them, and its note says why it draws
    # no line.
    def first_drawn_day
      boxed = drawn.filter_map { |number| counts.first_day(number.key, showing(number).select(&:boxed?).map(&:key)) }.min
      boxed || drawn.filter_map { |number| counts.first_day(number.key, showing(number).map(&:key)) }.min
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
