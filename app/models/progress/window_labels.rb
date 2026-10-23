module Progress
  # The words a Window goes by on the public page: what it spans, what its
  # change is measured against, its axis and its tooltips. Answers the
  # PeriodLabels calls the page and the tag line make.
  class WindowLabels
    SPANS = { "30d" => "30 days", "90d" => "90 days", "12m" => "12 months" }.freeze

    attr_reader :window

    delegate :range, :first, :today, :unit, to: :window

    def initialize(window)
      @window = window
    end

    # "last 90 days", "since March 2026".
    def words
      range == "all" ? "since #{first.strftime('%B %Y')}" : "last #{SPANS.fetch(range)}"
    end

    # What fits after "Nothing shipped or published": "in the last 90 days".
    def word
      range == "all" ? words : "in the #{words}"
    end

    alias phrase word

    def empty
      "Nothing shipped or published #{word}."
    end

    def empty_tagged(project, **)
      "No entries tagged #{project} #{word}."
    end

    # "vs the previous 90 days"; nil for all time.
    def versus
      "vs the previous #{SPANS.fetch(range)}" unless range == "all"
    end

    # "day", "week", "month": what one point on the chart counts.
    def unit_word
      unit.to_s
    end

    # Under the chart: "Jul 27", or "Nov 2025" for a month of another year.
    def axis(bucket)
      date = bucket.first
      return date.strftime("%b %-d") unless unit == :month

      date.year == today.year ? date.strftime("%b") : date.strftime("%b %Y")
    end

    def bucket_title(bucket)
      case unit
      when :day then bucket.first.strftime("%a, %b %-d")
      when :week then "Week of #{span(bucket.first, bucket.last)}"
      else bucket.first.strftime("%B %Y")
      end
    end

    private

    def span(from, to)
      return from.strftime("%b %-d") if from == to

      from.month == to.month ? "#{from.strftime('%b %-d')}–#{to.day}" : "#{from.strftime('%b %-d')} – #{to.strftime('%b %-d')}"
    end
  end
end
