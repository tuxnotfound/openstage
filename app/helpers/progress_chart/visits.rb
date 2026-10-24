module ProgressChart
  # The analytics page's chart: one line per page through the number picked,
  # a point per day or per week. It answers what Trend answers, so the public
  # page's chart partial draws it.
  class Visits
    WIDTH = Trend::WIDTH
    HEIGHT = Trend::HEIGHT
    HEADROOM = Trend::HEADROOM
    LABELS = { "visitors" => "Visitors", "views" => "Page views", "follows" => "New followers", "clicks" => "Clicks out" }.freeze

    Line = Data.define(:name, :rank, :values)

    def initialize(report)
      @report = report
    end

    def average?
      false
    end

    # The pages picked with anything in the window, the busiest drawn last.
    def lines
      @lines ||= @report.selected.filter_map do |page|
        values = @report.series(page)
        Line.new(name: page.name, rank: page.rank, values: values) if values.sum.positive?
      end
    end

    def paths
      lines.sort_by { |line| line.values.sum }.map do |line|
        [ line.values.each_with_index.map { |value, i| "#{i.zero? ? 'M' : 'L'}#{num(x(i))} #{num(y(value))}" }.join(" "), line.rank ]
      end
    end

    def ticks
      scale.drop(1).map { |value| Trend::Tick.new(value: value, top: top(value)) }
    end

    def axis
      buckets = window.buckets
      [ label(buckets.first.first), label(buckets[buckets.size / 2].first), "Today" ]
    end

    def columns
      count = window.buckets.size
      window.buckets.map do |bucket|
        i = bucket.index
        from = i.zero? ? 0 : (x(i - 1) + x(i)) / 2
        to = i == count - 1 ? WIDTH : (x(i) + x(i + 1)) / 2
        Trend::Column.new(left: pct(from), width: pct(to - from), mark: (100.0 * (x(i) - from) / (to - from)).round(1),
                          title: title(bucket), rows: rows_at(i), notes: [])
      end
    end

    def aria_label
      "#{name} per #{window.unit_word} by page, #{window.words}"
    end

    def note
      "#{name} per #{window.unit_word}, one line per page."
    end

    def none
      "Nothing"
    end

    def empty_note
      "No #{name.downcase} in the #{window.words}."
    end

    def name
      LABELS.fetch(@report.metric)
    end

    private

    def window
      @report.window
    end

    def rows_at(index)
      lines.select { |line| line.values[index].positive? }.sort_by { |line| -line.values[index] }
           .map { |line| Trend::Row.new(name: line.name, rank: line.rank, value: line.values[index]) }
    end

    def label(date)
      date.strftime("%b %-d")
    end

    # "Oct 3", "Oct 3–9" or "Sep 29–Oct 5".
    def title(bucket)
      return label(bucket.first) if bucket.first == bucket.last

      last = bucket.last.month == bucket.first.month ? bucket.last.day : label(bucket.last)
      "#{label(bucket.first)}–#{last}"
    end

    def scale
      @scale ||= Scale.ticks([ lines.flat_map(&:values).max.to_f, 4 ].max)
    end

    def top(value)
      (100.0 - (100.0 * value / (scale.last * HEADROOM))).round(2)
    end

    def x(index)
      count = window.buckets.size
      count == 1 ? WIDTH / 2.0 : index * WIDTH.to_f / (count - 1)
    end

    def y(value)
      HEIGHT * (1 - (value / (scale.last * HEADROOM)))
    end

    def pct(value)
      (100.0 * value / WIDTH).round(2)
    end

    def num(value)
      rounded = value.to_f.round(2)
      rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
    end
  end
end
