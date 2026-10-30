module Progress
  # The words a Window goes by on the public page: what it spans, its axis
  # and its tooltips. Answers the PeriodLabels calls the page and the tag
  # line make. Days the builder picked go by their dates: "3 Oct – 28 Oct",
  # each with its year when they are not all in this year.
  class WindowLabels
    SPANS = { "30d" => "30 days", "90d" => "90 days", "12m" => "12 months" }.freeze

    attr_reader :window

    delegate :range, :first, :today, :unit, :custom?, :picked, to: :window

    def initialize(window)
      @window = window
    end

    # "last 90 days", "since March 2026", "3 Oct – 28 Oct".
    def words
      return name if custom?

      range == "all" ? "since #{first.strftime('%B %Y')}" : "last #{SPANS.fetch(range)}"
    end

    # What a number's total covers: "last 90 days", "all time" or "3 Oct – 28 Oct".
    def span_words
      return name if custom?

      range == "all" ? "all time" : "last #{SPANS.fetch(range)}"
    end

    # What fits after "Nothing shipped or published": "in the last 90 days",
    # "between 3 Oct and 28 Oct", "on 3 Oct".
    def word
      return picked_word if custom?

      range == "all" ? words : "in the #{words}"
    end

    alias phrase word

    # The days picked: "3 Oct – 28 Oct", "3 Oct 2025 – 28 Jan 2026", "3 Oct";
    # nil for the others.
    def name
      return unless custom?

      picked.count == 1 ? date(picked.from) : "#{date(picked.from)} – #{date(picked.to)}"
    end

    # What the changes compare with: "the 90 days before", "the 26 days
    # before", "the day before"; nil for all time.
    def before
      return "the #{picked.count == 1 ? 'day' : "#{picked.count} days"} before" if custom?

      "the #{SPANS.fetch(range)} before" unless range == "all"
    end

    def empty
      "Nothing shipped or published #{word}."
    end

    def empty_tagged(project, **)
      "No entries tagged #{project} #{word}."
    end

    # "12m-2026-10-23", "all-time-2026-10-23", "2026-10-03-to-2026-10-28": a
    # card's file name.
    def file_name
      return "#{picked.from.iso8601}-to-#{picked.to.iso8601}" if custom?

      "#{range == 'all' ? 'all-time' : range}-#{today.iso8601}"
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

    # A month cut short by the days picked gives its days: "Oct 3–31, 2026".
    def bucket_title(bucket)
      case unit
      when :day then bucket.first.strftime("%a, %b %-d")
      when :week then "Week of #{span(bucket.first, bucket.last)}"
      else cut?(bucket) ? "#{span(bucket.first, bucket.last)}, #{bucket.first.year}" : bucket.first.strftime("%B %Y")
      end
    end

    private

    def picked_word
      picked.count == 1 ? "on #{name}" : "between #{date(picked.from)} and #{date(picked.to)}"
    end

    # "3 Oct", or "3 Oct 2025" when the days picked are not all in this year.
    def date(day)
      this_year = picked.from.year == today.year && picked.to.year == today.year
      day.strftime(this_year ? "%-d %b" : "%-d %b %Y")
    end

    def cut?(bucket)
      custom? && (bucket.first.day != 1 || (bucket.last != bucket.first.end_of_month && bucket.last != today))
    end

    def span(from, to)
      return from.strftime("%b %-d") if from == to

      from.month == to.month ? "#{from.strftime('%b %-d')}–#{to.day}" : "#{from.strftime('%b %-d')} – #{to.strftime('%b %-d')}"
    end
  end
end
