module ProgressChart
  # A chart of plain counts in Trend's box: one line per thing through its
  # count per point, with gridlines, the axis and a tooltip per point, so the
  # public page's chart partial draws it. The chart that includes it answers
  # lines (each with a name, a rank and a value per point) and buckets (each
  # with an index and its first and last day).
  module Plot
    WIDTH = Trend::WIDTH
    HEIGHT = Trend::HEIGHT
    HEADROOM = Trend::HEADROOM

    def average?
      false
    end

    def none
      "Nothing"
    end

    # The busiest line drawn last, on top.
    def paths
      lines.sort_by { |line| line.values.sum }.map do |line|
        [ line.values.each_with_index.map { |value, i| "#{i.zero? ? 'M' : 'L'}#{num(x(i))} #{num(y(value))}" }.join(" "), line.rank ]
      end
    end

    def ticks
      scale.drop(1).map { |value| Trend::Tick.new(value: value, top: top(value)) }
    end

    def axis
      return [ label(buckets.first.first), "Today" ] if buckets.size < 3

      [ label(buckets.first.first), label(buckets[buckets.size / 2].first), "Today" ]
    end

    def columns
      count = buckets.size
      buckets.map do |bucket|
        i = bucket.index
        from = i.zero? ? 0 : (x(i - 1) + x(i)) / 2
        to = i == count - 1 ? WIDTH : (x(i) + x(i + 1)) / 2
        Trend::Column.new(left: pct(from), width: pct(to - from), mark: (100.0 * (x(i) - from) / (to - from)).round(1),
                          title: title(bucket), rows: rows_at(i), notes: [])
      end
    end

    private

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
      count = buckets.size
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
