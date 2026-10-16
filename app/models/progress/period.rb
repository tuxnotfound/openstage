module Progress
  # A calendar period on the progress section: an ISO week, a month, a year,
  # or all time since the builder's first activity, cut into the chart's
  # buckets. Every date is a day in the builder's zone. Offset 0 is the period
  # holding today; earlier ones count back from it. A running period's buckets
  # stop at today: days still ahead would only be empty columns.
  class Period
    RANGES = %w[week month year all].freeze
    # A bucket is a day for Week and Month, an ISO week for Year, a month for All.
    UNITS = { "week" => :day, "month" => :day, "year" => :week, "all" => :month }.freeze

    # monday starts the bucket's ISO week, even when the period cuts it short.
    Bucket = Data.define(:index, :first, :last, :monday, :current)

    attr_reader :range, :offset, :today, :first_activity, :first, :last

    def initialize(range:, offset:, today:, first_activity:)
      @range = RANGES.include?(range) ? range : "year"
      @offset = @range == "all" ? 0 : [ offset.to_i, 0 ].min
      @today = today
      @first_activity = first_activity
      @first, @last = bounds
    end

    def unit
      UNITS.fetch(range)
    end

    def days
      first..last
    end

    def running?
      days.cover?(today)
    end

    # The period's last day, or today while it runs.
    def last_day
      [ last, today ].min
    end

    def previous
      self.class.new(range: range, offset: offset - 1, today: today, first_activity: first_activity) unless range == "all"
    end

    def previous?
      previous.present? && first_activity.present? && previous.last >= first_activity
    end

    # The same span of the period before, cut to as many days as this one has
    # had while it runs; nil before the builder's first activity.
    def comparison
      return unless previous?

      finish = running? ? [ previous.last, previous.first + (today - first) ].min : previous.last
      previous.first..finish
    end

    def buckets
      @buckets ||= spans.each_with_index.map do |(from, to, monday), index|
        Bucket.new(index: index, first: from, last: to, monday: monday, current: (from..to).cover?(today))
      end
    end

    def bucket_for(date)
      buckets.find { |bucket| (bucket.first..bucket.last).cover?(date) }
    end

    private

    def bounds
      case range
      when "week" then week_bounds
      when "month" then month_bounds
      when "year" then year_bounds
      else [ (first_activity || today).beginning_of_month, today.end_of_month ]
      end
    end

    def week_bounds
      monday = today - (today.cwday - 1) + (offset * 7)
      [ monday, monday + 6 ]
    end

    def month_bounds
      start = today.beginning_of_month >> offset
      [ start, start.end_of_month ]
    end

    def year_bounds
      year = today.year + offset
      [ Date.new(year, 1, 1), Date.new(year, 12, 31) ]
    end

    def spans
      case unit
      when :day then (first..last_day).map { |day| [ day, day, day ] }
      when :week then week_spans
      else month_spans
      end
    end

    def week_spans
      (first - (first.cwday - 1)).step(last_day, 7).map { |monday| [ [ monday, first ].max, [ monday + 6, last_day ].min, monday ] }
    end

    def month_spans
      months = []
      start = first
      while start <= last_day
        months << [ start, [ start.end_of_month, last_day ].min, start ]
        start = start.next_month.beginning_of_month
      end
      months
    end
  end
end
