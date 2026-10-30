module Progress
  # A stretch of the builder's work, as the public page shows it: the last
  # 30 days by day, the last 90 days by week (13 ISO weeks), the last 12
  # months by month, all time by month, or the days the builder picked
  # (Days), which may end before today. Picked days draw by day up to a
  # month, by ISO week up to half a year and by month past that, the first
  # and last week or month cut at the days picked. It starts no earlier than
  # the first activity in view (that day, its week or its month), so a chart
  # never draws the time before there was anything to count. It answers what
  # Period answers, so the tally and the picks read either.
  class Window
    RANGES = %w[30d 90d 12m all].freeze
    # Every chart page opens on the last 30 days.
    DEFAULT = "30d".freeze
    UNITS = { "30d" => :day, "90d" => :week, "12m" => :month, "all" => :month }.freeze
    # The most days picked that draw by day, and by week.
    DAILY = 31
    WEEKLY = 26 * 7
    # Work younger than the 90-day view draws by week in the longer views: a
    # month or two would leave the chart a point or two. A week is the finest
    # a short history draws.
    SHORT = 13.weeks
    # Days in a point's average, as the 30-day view's charts draw each day.
    AVERAGE = 7
    # The fewest days drawn by day that draw the average: under two weeks,
    # most of a point's average would count days before the window.
    AVERAGED = 2 * AVERAGE

    attr_reader :range, :today, :first_activity, :first, :picked

    # range: one of RANGES, or picked days as Days#to_s; anything else is
    # the default. Picked days end today at the latest.
    def initialize(range:, today:, first_activity:)
      @picked = Days.parse(range)&.upto(today)
      @range = picked&.to_s || (RANGES.include?(range) ? range : DEFAULT)
      @today = today
      @first_activity = first_activity
      @first = start
    end

    def custom?
      picked.present?
    end

    def unit
      short? ? :week : UNITS.fetch(range) { picked_unit }
    end

    # Today, or the last day picked.
    def last
      custom? ? picked.to : today
    end

    def last_day
      last
    end

    def days
      first..last
    end

    # Whether it ends today, so its last point is the one still counting.
    def running?
      last == today
    end

    # Whether each point is its day's 7-day average, as the 30-day view
    # draws commits: by day, over two weeks or more.
    def average?
      unit == :day && (range_start..last).count >= AVERAGED
    end

    def labels
      WindowLabels.new(self)
    end

    # The same stretch just before it, up to the same point: 30 or 91 days
    # back, a year back, or as many days back as were picked. nil for all
    # time, and when the builder's work began inside the window.
    def comparison
      return if range == "all" || first_activity.nil? || first_activity >= first

      back(first)..back(last)
    end

    # The whole range, wherever the activity in view begins: the days a
    # number's total for the window counts. nil for all time.
    def span
      range_start..last unless range == "all"
    end

    # The same stretch just before the whole range; nil for all time.
    def span_before
      back(range_start)..back(last) unless range == "all"
    end

    def buckets
      @buckets ||= spans.each_with_index.map do |(from, to, monday), index|
        Period::Bucket.new(index: index, first: from, last: to, monday: monday, current: running? && (from..to).cover?(today))
      end
    end

    def bucket_for(date)
      buckets.find { |bucket| (bucket.first..bucket.last).cover?(date) }
    end

    private

    # By month, a history younger than SHORT draws by week instead.
    def short?
      monthly = %w[12m all].include?(range) || (custom? && picked_unit == :month)
      monthly && begun.present? && begun > last - SHORT
    end

    # The first activity, when it came by the window's last day: days picked
    # before any work draw empty from their own first day.
    def begun
      first_activity if first_activity && first_activity <= last
    end

    def picked_unit
      return :day if picked.count <= DAILY

      picked.count <= WEEKLY ? :week : :month
    end

    def start
      begun ? [ range_start, aligned(begun) ].max : range_start
    end

    # Where the range itself begins, before the first activity has a say.
    def range_start
      return picked.from if custom?

      case range
      when "30d" then today - 29
      when "90d" then today - (today.cwday - 1) - (12 * 7)
      when "12m" then today.beginning_of_month << 11
      else first_activity ? aligned(first_activity) : today.beginning_of_month
      end
    end

    # The first activity's own day, week or month: where its bucket begins.
    def aligned(date)
      case unit
      when :day then date
      when :week then date - (date.cwday - 1)
      else date.beginning_of_month
      end
    end

    def back(date)
      return date - picked.count if custom?

      case range
      when "30d" then date - 30
      when "90d" then date - 91
      else date << 12
      end
    end

    # Each point's first and last day and the Monday of its week, the first
    # and last cut at the window's own days.
    def spans
      case unit
      when :day then days.map { |day| [ day, day, day ] }
      when :week then (first - (first.cwday - 1)).step(last, 7).map { |monday| [ [ monday, first ].max, [ monday + 6, last ].min, monday ] }
      else month_spans
      end
    end

    def month_spans
      months = []
      start = first
      while start <= last
        months << [ start, [ start.end_of_month, last ].min, start ]
        start = start.next_month.beginning_of_month
      end
      months
    end
  end
end
