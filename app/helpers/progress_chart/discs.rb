module ProgressChart
  # One numbered disc per bucket that holds listed entries, standing just
  # above its bar. Several entries in one bucket share a pill such as "2–3",
  # so discs never stack and the top tick never moves.
  #
  # Other discs and taller neighbouring bars push a disc sideways. Every spot
  # within two pills of its bar is weighed by the distance moved, squared,
  # plus 4 for each unit a taller bar would still lift it. The cheapest row of
  # spots that keeps every pair of discs apart wins, so a disc moves only as
  # far as it must and floats above its bar only when no spot beside it is
  # clear.
  class Discs
    STEP = 0.5
    LIFT_COST = 4

    # numbers: the listed entries' numbers, in date order. x and cy center it.
    Disc = Data.define(:bucket_index, :numbers, :items, :width, :x, :cy) do
      def label
        numbers.size > 1 ? "#{numbers.first}–#{numbers.last}" : numbers.first.to_s
      end

      def shipped?
        items.any?(&:shipped?)
      end
    end

    # size: a disc's diameter; pill: a pill's width; gap: the least space
    # between two; lift: the space between a disc and the bar under it.
    Shape = Data.define(:size, :pill, :gap, :lift)

    # A flat ground for circles on a track at y, under the chart: they spread
    # sideways without lifting, since no bar stands in their way.
    Ground = Data.define(:columns, :width, :frame)

    attr_reader :all

    def self.track(series, count, y, shape)
      top = y + shape.lift + (shape.size / 2.0)
      columns = Array.new(count) do |index|
        cx = series.center(index)
        Bars::Column.new(cx: cx, x: cx, top: top)
      end
      Ground.new(columns: columns, width: 0, frame: series.frame.with(bottom: top))
    end

    # kept: the listed entries in date order, numbered from 1.
    def initialize(kept, period:, bars:, shape:)
      @bars = bars
      @shape = shape
      groups = kept.each_with_index.group_by { |item, _k| period.bucket_for(item.date)&.index }.except(nil).sort
      widths = groups.map { |_index, pairs| pairs.size > 1 ? shape.pill : shape.size }
      xs = place(groups.map(&:first), widths)
      @all = groups.each_with_index.map do |(index, pairs), k|
        Disc.new(bucket_index: index, numbers: pairs.map { |_item, n| n + 1 }, items: pairs.map(&:first),
                 width: widths[k], x: xs[k], cy: reach_top(xs[k], widths[k]) - shape.lift - (shape.size / 2.0))
      end
    end

    private

    def place(indexes, widths)
      own = indexes.map { |index| @bars.columns[index].cx }
      return own if indexes.empty?

      spots = indexes.each_with_index.map { |index, k| spots_for(@bars.columns[index], widths[k]) }
      best, from = cheapest(spots, widths)
      j = best.last.each_with_index.min_by(&:first)&.last
      return own if j.nil? || best.last[j].infinite?

      (spots.size - 1).downto(0).map { |k| spots[k][j][:x].tap { j = from[k][j] } }.reverse
    end

    def spots_for(column, width)
      reach = (2 * @shape.pill / STEP).round
      (-reach..reach).filter_map do |q|
        x = column.cx + (q * STEP)
        next unless x - (width / 2.0) >= @bars.frame.left && x + (width / 2.0) <= @bars.frame.right

        { x: x, cost: ((q * STEP)**2) + (LIFT_COST * [ 0, column.top - reach_top(x, width) ].max) }
      end
    end

    # best[k][j]: the cheapest way to stand discs 0..k with disc k on spot j.
    def cheapest(spots, widths)
      best = [ spots.first.map { |spot| spot[:cost] } ]
      from = [ Array.new(spots.first.size, -1) ]
      (1...spots.size).each do |k|
        apart = ((widths[k - 1] + widths[k]) / 2.0) + @shape.gap
        best[k], from[k] = follow(spots[k - 1], best[k - 1], spots[k], apart)
      end
      [ best, from ]
    end

    def follow(before, before_best, row, apart)
      p = 0
      low = Float::INFINITY
      at = -1
      costs = row.map do |spot|
        while p < before.size && before[p][:x] <= spot[:x] - apart + 1e-9
          low, at = before_best[p], p if before_best[p] < low
          p += 1
        end
        [ at.negative? ? Float::INFINITY : low + spot[:cost], at ]
      end
      costs.transpose.presence || [ [], [] ]
    end

    # The top of the highest bar a disc standing at x would touch, with 1px
    # to spare; the baseline where it touches none.
    def reach_top(x, width)
      half = (width / 2.0) + 1
      touched = @bars.columns.select { |column| column.x < x + half && column.x + @bars.width > x - half }
      touched.map(&:top).min || @bars.frame.bottom
    end
  end
end
