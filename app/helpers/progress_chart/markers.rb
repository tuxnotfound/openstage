module ProgressChart
  # Under a project filter the numbered circles stand on the project's line,
  # one per bin of time holding listed entries, at the middle of the bin's
  # buckets so far. A bin is a bucket, or a week or a month when buckets are
  # too narrow for a pill to stand clear of the next one, as on the Journey
  # page, so circles never touch.
  class Markers
    # A day, a week, a month: the next wider bin.
    WIDER = { day: :week, week: :month }.freeze

    attr_reader :all

    def initialize(kept, period:, lines:, repo:, shape:)
      @period = period
      @lines = lines
      @points = lines.points(repo)
      @unit = unit_for(shape.pill + shape.gap)
      groups = kept.each_with_index.group_by { |item, _k| bin_of(item.date) }.sort_by(&:first)
      @all = groups.filter_map { |bin, pairs| disc(bin, pairs, shape) }
    end

    private

    def unit_for(room)
      unit = @period.unit
      unit = WIDER.fetch(unit) while WIDER.key?(unit) && @lines.slot * days_in(unit) < room
      unit
    end

    # How many buckets a bin of this unit spans, about.
    def days_in(unit)
      { day: { day: 1, week: 7, month: 30 }, week: { week: 1, month: 4.3 }, month: { month: 1 } }.fetch(@period.unit).fetch(unit)
    end

    def bin_of(date)
      case @unit
      when :day then date
      when :week then date - (date.cwday - 1)
      else date.beginning_of_month
      end
    end

    def bin_end(bin)
      case @unit
      when :day then bin
      when :week then bin + 6
      else bin.end_of_month
      end
    end

    def disc(bin, pairs, shape)
      indexes = buckets_in(bin)
      return if indexes.empty?

      x = [ (@lines.center(indexes.first) + @lines.center(indexes.last)) / 2.0, @points.last.first ].min
      width = pairs.size > 1 ? shape.pill : shape.size
      Discs::Disc.new(bucket_index: indexes.first, numbers: pairs.map { |_item, n| n + 1 }, items: pairs.map(&:first),
                      width: width, x: x, cy: line_y(x))
    end

    # The bin's buckets up to today.
    def buckets_in(bin)
      last = [ bin_end(bin), @period.today ].min
      @period.buckets.select { |bucket| bucket.last >= bin && bucket.first <= last }.map(&:index)
    end

    def line_y(x)
      @points.each_cons(2) do |(x0, y0), (x1, y1)|
        next unless x.between?(x0, x1)

        return x1 == x0 ? y1 : y0 + ((y1 - y0) * (x - x0) / (x1 - x0))
      end
      @points.last.last
    end
  end
end
