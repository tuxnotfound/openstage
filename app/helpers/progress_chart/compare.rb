module ProgressChart
  # Every chart page's chart: a line per project and number on a window's
  # points, in the project's colour and its number's line style. The browser
  # gives a number its style by its place in its own line order (the first
  # solid, the second dotted, the third dashed); the server's first paint, by
  # its place among the numbers drawn. With two or three numbers that have
  # lines, each is drawn against its own peak in the window, its projects on
  # one scale so they still compare; with one, the axis is that number's own.
  # The tooltip keeps the real numbers: a row per project with anything at
  # the point, a column per number. The words are CompareNote's.
  class Compare
    WIDTH = Trend::WIDTH
    HEIGHT = Trend::HEIGHT
    PEAK = 100.0

    # rank: its row's place in the table; color_class: the class it wears
    # (Palette); number: a Progress::Numbers::Number; values: one per point;
    # total: its count over the window's days, without which it draws no line.
    Line = Data.define(:repo, :name, :rank, :color_class, :number, :values, :total)
    # values: one per number with lines; "–" where the project has none of it.
    Row = Data.define(:repo, :name, :color_class, :values)
    Column = Data.define(:left, :width, :mark, :title, :rows)

    # numbers: the numbers drawn, in line order. average: each point a 7-day
    # average. lone: one project's page. per: what a line's row is, "project"
    # or, on analytics, "page".
    attr_reader :window, :numbers, :every_line, :lone, :per

    delegate :note, :note_parts, :aria_label, :none, to: :words

    def initialize(window:, lines:, numbers:, average: false, lone: false, per: "project")
      @window = window
      @every_line = lines
      @numbers = numbers
      @average = average
      @lone = lone
      @per = per
    end

    # The lines with anything in the window.
    def lines
      @lines ||= every_line.select { |line| line.total.positive? }
    end

    # The numbers drawn that have lines, in the pages' order: the tooltip's columns.
    def lined
      @lined ||= Progress::Numbers::ALL.select { |number| lines.any? { |line| line.number == number } }
    end

    def indexed?
      lined.size > 1
    end

    def average?
      @average
    end

    # [d, color class, number's key, repo]: the later numbers in line order
    # first, and each number's busiest line last, so it draws on top.
    def paths
      lines.sort_by { |line| [ -numbers.index(line.number).to_i, line.values.sum ] }.map do |line|
        d = line.values.each_with_index.map { |value, i| "#{i.zero? ? 'M' : 'L'}#{num(x(i))} #{num(y(line.number, value))}" }.join(" ")
        [ d, line.color_class, line.number.key, line.repo ]
      end
    end

    # None without a line, so an empty chart suggests no scale.
    def ticks
      return [] if lines.empty?
      return [ PEAK / 2, PEAK ].map { |value| Trend::Tick.new(value: "#{value.to_i}%", top: top(value)) } if indexed?

      scale.drop(1).map { |value| Trend::Tick.new(value: words.tick(lined.first, value), top: top(value)) }
    end

    def columns
      buckets = window.buckets
      buckets.map { |bucket| column(bucket, buckets.size) }
    end

    # The first point, the middle one and today, under the chart.
    def axis
      buckets = window.buckets
      return [ window.labels.axis(buckets.first), "Today" ] if buckets.size < 3

      [ window.labels.axis(buckets.first), window.labels.axis(buckets[buckets.size / 2]), "Today" ]
    end

    # A number's highest value in the window, over every project: its 100%.
    def peak(number)
      lines.select { |line| line.number == number }.flat_map(&:values).max.to_f
    end

    private

    def words
      @words ||= CompareNote.new(self)
    end

    def column(bucket, count)
      i = bucket.index
      from = i.zero? ? 0 : (x(i - 1) + x(i)) / 2
      to = i == count - 1 ? WIDTH : (x(i) + x(i + 1)) / 2
      Column.new(left: pct(from), width: pct(to - from), mark: (100.0 * (x(i) - from) / (to - from)).round(1),
                 title: "#{window.labels.bucket_title(bucket)}#{' · 7-day average' if average?}", rows: rows_at(i))
    end

    # A row per project with anything at the point, in the table's order:
    # by rank, after the builder's own page (analytics' one row with none).
    def rows_at(index)
      projects = lines.select { |line| line.values[index].positive? }.map { |line| [ line.repo, line.name, line.rank, line.color_class ] }.uniq
      projects.sort_by { |_, name, rank| [ rank || -1, name ] }.map do |repo, name, _rank, color_class|
        Row.new(repo: repo, name: name, color_class: color_class, values: lined.map { |number| value_at(repo, number, index) })
      end
    end

    def value_at(repo, number, index)
      line = every_line.find { |each| each.repo == repo && each.number == number }
      line ? words.amount(number, line.values[index]) : "–"
    end

    def x(index)
      count = window.buckets.size
      count == 1 ? WIDTH / 2.0 : index * WIDTH.to_f / (count - 1)
    end

    # A value's height: against its number's peak when the chart compares numbers.
    def y(number, value)
      return HEIGHT * (1 - (value / ceiling)) unless indexed?

      peak = peaks.fetch(number)
      HEIGHT * (1 - ((peak.positive? ? PEAK * value / peak : 0) / ceiling))
    end

    def peaks
      @peaks ||= lined.to_h { |number| [ number, peak(number) ] }
    end

    # Nice steps over the busiest point; whole counts unless averaged.
    def scale
      @scale ||= Scale.ticks([ lines.flat_map(&:values).max.to_f, average? ? 1 : 4 ].max)
    end

    def ceiling
      (indexed? ? PEAK : scale.last) * Trend::HEADROOM
    end

    def top(value)
      (100.0 - (100.0 * value / ceiling)).round(2)
    end

    def pct(value)
      (100.0 * value / WIDTH).round(2)
    end

    # 12.5 or 12, never 12.0, so the paths stay short.
    def num(value)
      rounded = value.to_f.round(2)
      rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
    end
  end
end
