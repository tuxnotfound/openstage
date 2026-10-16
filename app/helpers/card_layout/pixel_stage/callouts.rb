module CardLayout
  class PixelStage
    # The callouts and the ground under each day. A callout holds a headline
    # in the builder's own words, with a dotted tail down to what it is about;
    # launch callouts lead in gold, the rest sit back. Under each day, its name
    # and its commits, or that it touched grass.
    class Callouts
      def initialize(stage)
        @stage = stage
        @dark = stage.dark
      end

      def draw
        @stage.days.each { |day| callout(day) if day.box }
        @stage.days.each { |day| label(day) }
      end

      private

      def callout(day)
        frame(day)
        tail(day.tail) if day.tail
        box = day.box
        tag, color = tag(day)
        @stage.text(tag, x: box[:x] + 14, y: box[:y] + 14, w: box[:w] - 28, size: 8, color: color)
        ink = @dark ? (day.shipped? ? "#FFFFFF" : "#E4E2F0") : "#1B1F3B"
        box[:lines].each_with_index do |line, i|
          @stage.text(line, x: box[:x] + 14, y: box[:y] + 26 + (i * box[:lh]), w: box[:w] - 28, size: box[:size], lh: box[:lh],
                            face: :pixelify_medium, color: ink)
        end
      end

      def tag(day)
        return [ "SHIPPED!", @dark ? "#FFD54A" : "#B7791F" ] if day.shipped?
        return [ "POSTED", @dark ? "#7FD4FF" : "#1D7FC4" ] if day.posted?

        [ "BUILT", @dark ? "#9BE38A" : "#2F8A3A" ]
      end

      def frame(day)
        day.shipped? ? gold_frame(day.box) : plain_frame(day.box)
      end

      def inset(box, by)
        @stage.notch(box[:x] + by, box[:y] + by, box[:w] - (2 * by), box[:h] - (2 * by))
      end

      def gold_frame(box)
        @stage.put(:box_shadow, @dark ? "#000000" : "#1B1F3B", @stage.notch(box[:x] + P, box[:y] + P, box[:w], box[:h]), @dark ? 0.4 : 0.25)
        @stage.put(:box_outer, @dark ? "#03040E" : "#1B1F3B", inset(box, 0))
        @stage.put(:box_mid, "#FFCB2E", inset(box, P))
        @stage.put(:box_inner, @dark ? "#141A4A" : "#FFFDF4", inset(box, 2 * P))
      end

      def plain_frame(box)
        @stage.put(:box_outer, @dark ? "#03040E" : "#1B1F3B", inset(box, 0), @dark ? 0.85 : 0.75)
        @stage.put(:box_inner, @dark ? "#0B0F2C" : "#FFFFFF", inset(box, P), @dark ? 0.82 : 0.86)
      end

      def tail(tail)
        dots = (tail[:y0]..(tail[:y1] - P)).step(12).map { |y| @stage.rect(tail[:x], y, P, P) }.join
        @stage.put(:tails, @dark ? "#E9E6F2" : "#1B1F3B", dots, 0.6)
      end

      def label(day)
        @stage.text(day.label, x: day.zx, y: GY + 14, w: 150, align: "center", size: 16, color: @stage.ground[:label],
                               shadow: @stage.hard_shadow(16, "#000000"))
        words = if day.total.positive? then "#{day.total} COMMIT#{'S' unless day.total == 1}"
        elsif day.has? then "NO COMMITS"
        else "TOUCHED GRASS"
        end
        @stage.text(words, x: day.zx, y: GY + 38, w: 150, align: "center", size: 8, color: day.total.positive? ? "#FFD54A" : @stage.ground[:mute])
      end
    end
  end
end
