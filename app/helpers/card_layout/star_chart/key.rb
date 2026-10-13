module CardLayout
  class StarChart
    # Two lines under the chart, in readable type. The first reads the dial: a
    # ring per day, and a star per hour with commits, sized by how many (drawn
    # at sky size for 1, 5 and 10). The second names the marks, the dust (with
    # the day the history starts) and the clock. The dust is drawn only
    # because the key names it.
    class Key
      SIZE = 12
      LINES = [ 572, 590 ].freeze
      LINE_H = 18
      # Clear of the link, which ends at x = 570.
      ROOM = 548
      MONTHS = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].freeze
      Size = Data.define(:count, :r, :halo, :center, :c, :w)

      # marks: what the partial draws, each { kind:, x:, y: } and, for a star
      # size, its Size.
      attr_reader :marks

      def initialize(chart)
        @chart = chart
        @canvas = chart.canvas
        @palette = chart.palette
        @marks = []
        gap, dust, local_up = ladder
        line_one(gap, local_up)
        line_two(gap, dust, local_up)
      end

      private

      def sans(text)
        CardText.width(text, size: SIZE, face: :dm_sans_regular)
      end

      def mono(text)
        CardText.width(text, size: 11, face: :dm_mono_regular)
      end

      def sizes
        @sizes ||= [ 1, 5, 10 ].map do |count|
          r = 1.3 + (1.9 * Math.sqrt(count))
          c = r + 1.5
          Size.new(count: count.to_s, r: r, halo: r + 1.6, center: [ 0.9, r * 0.42 ].max, c: c, w: 2 * c)
        end
      end

      def widths
        @widths ||= {
          rings: 14 + 6 + sans("Each ring is a day"),
          sizes: sizes.sum { |size| size.w.round(1) + mono(size.count) + 3 } + 20 + 6 + sans("commits in an hour"),
          shipped: 14 + 5 + sans("Shipped"), published: 14 + 5 + sans("Published"), local: 12 + 6 + sans("Local time")
        }
      end

      # The dust count holds out longest: first "Local time" moves up to the
      # first line, then the gaps close, then the dust copy shortens.
      def ladder
        dust_copies.each do |dust|
          [ 20, 16 ].each do |gap|
            [ false, true ].each do |local_up|
              return [ gap, dust, local_up ] if width_one(gap, local_up) <= ROOM && width_two(gap, dust, local_up) <= ROOM
            end
          end
        end
        [ 16, nil, false ]
      end

      def width_one(gap, local_up)
        widths[:rings] + gap + widths[:sizes] + (local_up ? gap + widths[:local] : 0)
      end

      def width_two(gap, dust, local_up)
        widths[:shipped] + gap + widths[:published] + (dust ? gap + 12 + 6 + sans(dust) : 0) + (local_up ? 0 : gap + widths[:local])
      end

      def dust_copies
        stars = @chart.stars
        return [ nil ] if stars.dust_count.zero?

        count, since = stars.dust_count.to_fs(:delimited), since_text
        per = stars.dust_step > 1 ? ", 1 dot per #{stars.dust_step}" : ""
        [ "#{count} earlier commits since #{since}, at their day and hour#{per}", "#{count} earlier commits since #{since}#{per}",
          "Earlier commits since #{since}#{per}" ]
      end

      def since_text
        since = @chart.card.history.since
        since.year == @chart.card.week_card.days.last.year ? "#{MONTHS[since.month - 1]} #{since.day}" : "#{MONTHS[since.month - 1]} #{since.year}"
      end

      def text(words, x, top)
        @canvas.put(words, :dm_sans_regular, SIZE, x, top + StarChart.base_in(LINE_H, SIZE), @palette[:key_text])
      end

      def mark(kind, x, top, size, gap)
        @marks << { kind: kind, x: x, y: top + ((LINE_H - size) / 2.0) }
        x + size + gap
      end

      def line_one(gap, local_up)
        top = LINES.first
        x = (C[:x] - (width_one(gap, local_up) / 2.0)).round
        x = text("Each ring is a day", mark(:rings, x, top, 14, 6), top) + gap
        x = text("commits in an hour", star_sizes(x, top) + 6, top) + gap
        text("Local time", mark(:clock, x, top, 12, 6), top) if local_up
      end

      # The three sample stars and their counts.
      def star_sizes(x, top)
        sizes.each_with_index.inject(x) do |at, (size, i)|
          @marks << { kind: :size, x: at, y: top, size: size }
          end_x = @canvas.put(size.count, :dm_mono_regular, 11, at + size.w + 4, top + StarChart.base_in(LINE_H, 11), @palette[:key_text])
          end_x + (i < 2 ? 3 + 4 : 0)
        end
      end

      def line_two(gap, dust, local_up)
        top = LINES.last
        x = (C[:x] - (width_two(gap, dust, local_up) / 2.0)).round
        x = text("Shipped", mark(:nova, x, top, 14, 5), top) + gap
        x = text("Published", mark(:comet, x, top, 14, 5), top) + gap
        x = text(dust, mark(:dust, x, top, 12, 6), top) + gap if dust
        text("Local time", mark(:clock, x, top, 12, 6), top) unless local_up
      end
    end
  end
end
