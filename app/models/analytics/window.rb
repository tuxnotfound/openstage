module Analytics
  # The days a Pro builder's numbers cover: the last 7, 30 or 90 days ending
  # today in their zone, against as many days just before. 7 and 30 days are
  # drawn a point per day; 90 days a point per week, the last one ending today.
  class Window
    RANGES = { "7d" => 7, "30d" => 30, "90d" => 91 }.freeze
    DEFAULT = "30d".freeze

    # first and last are dates, inclusive.
    Bucket = Data.define(:index, :first, :last)

    attr_reader :range, :today

    def initialize(range:, today:)
      @range = RANGES.key?(range) ? range : DEFAULT
      @today = today
    end

    def length
      RANGES.fetch(range)
    end

    def days
      (today - (length - 1))..today
    end

    def previous_days
      (days.first - length)..(days.first - 1)
    end

    # Both windows, for one query that covers them.
    def span
      previous_days.first..today
    end

    def weekly?
      range == "90d"
    end

    def buckets
      step = weekly? ? 7 : 1
      days.step(step).each_with_index.map { |first, index| Bucket.new(index: index, first: first, last: [ first + step - 1, today ].min) }
    end

    # "last 30 days", and the "30 days" before them.
    def words
      "last #{label}"
    end

    def label
      range == "90d" ? "90 days" : "#{length} days"
    end

    def unit_word
      weekly? ? "week" : "day"
    end
  end
end
