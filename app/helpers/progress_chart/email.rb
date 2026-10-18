module ProgressChart
  # The progress section's Bars chart for an email, drawn as table cells:
  # mail clients run no script and Gmail shows no SVG. The discs are the
  # page's (ProgressChart::Page), each standing over its own day's bar, so the
  # numbers match the list under the chart and the page the email links to.
  class Email
    # The busiest bucket's bar, in pixels.
    BAR_HEIGHT = 96
    # Room over the bars for a row of discs.
    DISC_ROOM = 28
    # A lone commit beside a busy day still shows.
    MIN_SEGMENT = 3

    # segments: top first, as the cells are written.
    Day = Data.define(:label, :current, :segments, :discs)
    Segment = Data.define(:color, :height)

    delegate :legend, to: :@page

    def initialize(section)
      @section = section
      @page = Page.new(section, "bars")
    end

    def days
      @days ||= tally.buckets.map do |bucket|
        span = bucket.span
        Day.new(label: labels.axis(span), current: labels.axis_tone(span) == :now,
                segments: segments(bucket), discs: @page.discs.select { |disc| disc.bucket_index == span.index })
      end
    end

    def column_height
      BAR_HEIGHT + DISC_ROOM
    end

    private

    def tally
      @section.tally
    end

    def labels
      @section.labels
    end

    # Stacked as the page stacks them: the busiest project of all time at the bottom.
    def segments(bucket)
      stacked = bucket.counts.select { |_repo, n| n.positive? }.sort_by { |repo, _n| order.index(repo) || order.size }
      stacked.reverse.map do |repo, n|
        Segment.new(color: Palette.project_color(repo && tally.projects.find(repo)&.rank),
                    height: [ (n * BAR_HEIGHT.to_f / busiest).round, MIN_SEGMENT ].max)
      end
    end

    def order
      @order ||= tally.projects.all.map(&:repo)
    end

    def busiest
      @busiest ||= [ tally.buckets.map(&:total).max.to_i, 1 ].max
    end
  end
end
