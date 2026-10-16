module Progress
  # The words a period goes by on the page and the cards: its heading, the
  # axis under the chart, tooltips, the empty lines and what the change is
  # measured against.
  class PeriodLabels
    # Days of the month that carry a label on the Month axis.
    MONTH_TICKS = [ 1, 8, 15, 22, 29 ].freeze

    attr_reader :period

    delegate :range, :first, :last, :today, :running?, :last_day, to: :period

    def initialize(period)
      @period = period
    end

    def title
      case range
      when "week" then "Week #{first.cweek}"
      when "month" then first.strftime("%B %Y")
      when "year" then first.year.to_s
      else "All time"
      end
    end

    def subtitle
      case range
      when "week" then "#{span(first, last)}, #{last.year}#{' · so far' if running?}"
      when "month" then running? ? "#{span(first, last_day)} · so far" : span(first, last)
      when "year" then running? ? "Jan 1 – #{day(last_day)} · so far" : "Jan 1 – Dec 31"
      else "Since #{first.strftime('%B %Y')}"
      end
    end

    # The heading between the period arrows.
    def nav
      case range
      when "week" then "#{title} · #{span(first, last)}"
      when "all" then "Since #{first.strftime('%b %Y')}"
      else title
      end
    end

    # "Week 42", "October", "2026", "All time": the period in a post.
    def short
      range == "month" ? first.strftime("%B") : title
    end

    def tag
      "PROGRESS · #{range == 'all' ? 'ALL TIME' : range.upcase}"
    end

    # "in October", "this week": what fits after "Nothing shipped or published".
    def word
      case range
      when "week" then running? ? "this week" : "in Week #{first.cweek}"
      when "month" then "in #{first.strftime('%B')}"
      when "year" then "in #{first.year}"
      else "so far"
      end
    end

    # "in October 2026", "in 2026", "this week", "since March 2026".
    def phrase
      case range
      when "month" then "in #{title}"
      when "all" then "since #{first.strftime('%B %Y')}"
      else word
      end
    end

    def file_name
      case range
      when "week" then first.strftime("%G-w%V")
      when "month" then first.strftime("%Y-%m")
      when "year" then first.year.to_s
      else "all-time"
      end
    end

    def empty
      "Nothing shipped or published #{word}#{' yet' if running? && range != 'all'}."
    end

    # yet: the cards add it while the period runs.
    def empty_tagged(project, yet: false)
      "No entries tagged #{project} #{range == 'all' ? 'yet' : word}#{' yet' if yet && running? && range != 'all'}."
    end

    # What the KPI changes are measured against; nil without a comparison.
    def versus
      before = period.comparison
      return unless before

      case range
      when "week" then running? ? "vs Mon–#{today.strftime('%a')} last week" : "vs Week #{before.first.cweek}"
      when "month" then running? ? "vs #{span(before.first, before.last)}" : "vs #{before.first.strftime('%B')}"
      else running? ? "vs #{before.first.year} to #{day(before.last)}" : "vs #{before.first.year}"
      end
    end

    # One label per bucket, or "" where the axis stays quiet.
    def axis(bucket)
      date = bucket.first
      case range
      when "week" then date.strftime("%a %-d")
      when "month" then month_axis(bucket)
      when "year" then new_month?(bucket) ? thursday(bucket).strftime("%b") : ""
      else bucket.index.zero? || date.month == 1 ? date.strftime("%b %Y") : date.strftime("%b")
      end
    end

    # :now, :future or :past, for the axis label's ink. On the Year axis a
    # label names a month, so the month holding today is the current one.
    def axis_tone(bucket)
      if range == "year"
        month = thursday(bucket).all_month
        return :now if month.cover?(today)

        return month.first > today ? :future : :past
      end
      bucket.current ? :now : (bucket.future ? :future : :past)
    end

    def bucket_title(bucket)
      case period.unit
      when :day then bucket.first.strftime("%a, %b %-d")
      when :week then "Week of #{span(bucket.first, bucket.last)}"
      else bucket.first.strftime("%B %Y")
      end
    end

    private

    def day(date)
      date.strftime("%b %-d")
    end

    def span(from, to)
      return day(from) if from == to

      from.month == to.month ? "#{day(from)}–#{to.day}" : "#{day(from)} – #{day(to)}"
    end

    def month_axis(bucket)
      date = bucket.first
      return date.day == 1 ? day(date) : date.day.to_s if MONTH_TICKS.include?(date.day)

      bucket.current ? date.day.to_s : ""
    end

    # A Year bucket belongs to the month its Thursday falls in, as ISO weeks do.
    def new_month?(bucket)
      bucket.index.zero? || thursday(bucket).month != thursday(period.buckets[bucket.index - 1]).month
    end

    def thursday(bucket)
      bucket.monday + 3
    end
  end
end
