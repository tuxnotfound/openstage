module CardLayout
  class Journey
    # The time axis under the Journey card's chart. A week names every day; a
    # month its week starts and today, or every day (every 2nd or 3rd on a
    # longer one) when a late first commit leaves fewer than three week starts;
    # Year and All name their months. A label that would touch the next one
    # goes, so a dense axis stays legible.
    class Axis
      Label = Data.define(:x, :text, :today)
      WEEK_STARTS = [ 1, 8, 15, 22, 29 ].freeze
      GAP = 8

      def initialize(geometry, period)
        @geometry = geometry
        @period = period
      end

      def labels
        declutter(@geometry.by_day ? day_labels : month_labels)
      end

      private

      def day_labels
        days = @geometry.bins(:day).map(&:first)
        step = dense?(days) ? dense_step(days.size) : 0
        days.each_with_index.filter_map do |day, i|
          next unless named?(day, i, step)

          Label.new(x: @geometry.x_at(i + 0.5), text: day_text(day).upcase, today: day == @period.today)
        end
      end

      def named?(day, index, step)
        return true if @period.range == "week" || day == @period.today

        step.positive? ? (index % step).zero? : WEEK_STARTS.include?(day.day)
      end

      def day_text(day)
        if @period.range == "week" then day.strftime("%a %-d")
        elsif day.day == 1 then day.strftime("%b 1")
        else day.day.to_s
        end
      end

      def dense?(days)
        @period.range == "month" && days.count { |day| WEEK_STARTS.include?(day.day) } < 3
      end

      def dense_step(count)
        if count <= 9 then 1
        elsif count <= 16 then 2
        else 3
        end
      end

      def month_labels
        @geometry.bins(:month).each_with_index.map do |(from, to), i|
          middle = ((from - @geometry.first).to_i + (to + 1 - @geometry.first).to_i) / 2.0
          year = @period.range == "all" && (i.zero? || from.month == 1)
          Label.new(x: @geometry.x_at(middle), text: from.strftime(year ? "%b %Y" : "%b").upcase,
                    today: from.all_month.cover?(@period.today))
        end
      end

      def declutter(labels)
        kept = []
        labels.reverse_each do |label|
          width = Type.width(label.text, :dm_mono_medium, 11, 0.08)
          last = kept.last
          kept << [ label, width ] if last.nil? || last.first.x - (last.last / 2) - GAP >= label.x + (width / 2)
        end
        kept.reverse.map(&:first)
      end
    end
  end
end
