module Progress
  # A stretch of the builder's work that ends today, as the public page shows
  # it: the last 30 days by day, the last 90 days by week (13 ISO weeks), the
  # last 12 months by month, or all time by month. It answers what Period
  # answers, so the tally and the picks read either; the cards keep calendar
  # periods.
  class Window
    RANGES = %w[30d 90d 12m all].freeze
    DEFAULT = "12m".freeze
    UNITS = { "30d" => :day, "90d" => :week, "12m" => :month, "all" => :month }.freeze

    attr_reader :range, :today, :first_activity, :first

    def initialize(range:, today:, first_activity:)
      @range = RANGES.include?(range) ? range : DEFAULT
      @today = today
      @first_activity = first_activity
      @first = start
    end

    def unit
      UNITS.fetch(range)
    end

    def last
      today
    end

    def last_day
      today
    end

    def days
      first..today
    end

    def running?
      true
    end

    def labels
      WindowLabels.new(self)
    end

    # The same stretch just before it, up to the same point: 30 or 91 days
    # back, or a year back. nil for all time, and when the builder's work
    # began inside the window.
    def comparison
      return if range == "all" || first_activity.nil? || first_activity >= first

      back(first)..back(today)
    end

    def buckets
      @buckets ||= spans.each_with_index.map do |(from, to, monday), index|
        Period::Bucket.new(index: index, first: from, last: to, monday: monday, current: (from..to).cover?(today))
      end
    end

    def bucket_for(date)
      buckets.find { |bucket| (bucket.first..bucket.last).cover?(date) }
    end

    private

    def start
      case range
      when "30d" then today - 29
      when "90d" then today - (today.cwday - 1) - (12 * 7)
      when "12m" then today.beginning_of_month << 11
      else (first_activity || today).beginning_of_month
      end
    end

    def back(date)
      case range
      when "30d" then date - 30
      when "90d" then date - 91
      else date << 12
      end
    end

    def spans
      case unit
      when :day then days.map { |day| [ day, day, day ] }
      when :week then first.step(today, 7).map { |monday| [ monday, [ monday + 6, today ].min, monday ] }
      else month_spans
      end
    end

    def month_spans
      months = []
      start = first
      while start <= today
        months << [ start, [ start.end_of_month, today ].min, start ]
        start = start.next_month
      end
      months
    end
  end
end
