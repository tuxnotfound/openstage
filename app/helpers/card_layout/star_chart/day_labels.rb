module CardLayout
  class StarChart
    # Each ring crosses the horizontal line twice, at 6h on the right and 18h
    # on the left: SUN … MON [avatar] MON … SUN. Every name sits on a small
    # dark backing, so stars near 6 AM and 6 PM never collide with it, and a
    # name steps aside when a mark sits on its spot while the other side still
    # names the ring.
    class DayLabels
      SIZE = 9.5
      SPACING = 0.5
      W = 21
      H = 13
      Label = Data.define(:text, :x, :y, :on)
      Box = Data.define(:x0, :y0, :x1, :y1)

      # backs: one path for every backing.
      attr_reader :labels, :backs

      def initialize(chart)
        @chart = chart
        @stars = chart.stars
        slots = [ 1, -1 ].flat_map { |side| chart.days.map { |day| slot(day, side) } }
        kept = slots.reject { |slot| slot[:hit] && !(slot[:side] == 1 && mirror(slots, slot)[:hit]) }
        @backs = kept.map { |slot| back(slot[:box]) }.join
        # Chrome adds the letter spacing after the last glyph, so the middle
        # anchor sits half a spacing left of true centre.
        @labels = kept.map do |slot|
          Label.new(text: slot[:day].label.split.first, x: StarChart.f1(slot[:x] + (SPACING / 2)), y: StarChart.f1(C[:y] + 3.4), on: slot[:day].active?)
        end
      end

      private

      def slot(day, side)
        x = C[:x] + (side * @chart.ring(day.index))
        box = Box.new(x0: x - (W / 2.0), y0: C[:y] - (H / 2.0), x1: x + (W / 2.0), y1: C[:y] + (H / 2.0))
        { day: day, side: side, x: x, box: box, hit: hit?(box) }
      end

      def mirror(slots, slot)
        slots.find { |other| other[:day] == slot[:day] && other[:side] != slot[:side] }
      end

      def hit?(box)
        @stars.list.any? { |star| circle?(box, star.x, star.y, (star.r * 1.6) + 1) } ||
          @stars.novas.any? { |x, y| circle?(box, x, y, 13) } ||
          @stars.comets.any? { |comet| circle?(box, *comet.head, 7 * comet.scale) || crosses?(box, comet.head, comet.tail_end) || crosses?(box, comet.head, comet.dust_end) }
      end

      def circle?(box, x, y, r)
        dx = [ box.x0 - x, 0, x - box.x1 ].max
        dy = [ box.y0 - y, 0, y - box.y1 ].max
        (dx**2) + (dy**2) < r**2
      end

      def crosses?(box, from, to)
        (0..8).any? do |k|
          x = from[0] + ((to[0] - from[0]) * k / 8.0)
          y = from[1] + ((to[1] - from[1]) * k / 8.0)
          x > box.x0 && x < box.x1 && y > box.y0 && y < box.y1
        end
      end

      def back(box)
        f1 = ->(value) { StarChart.f1(value) }
        x0, y0, r = box.x0, box.y0, 3
        "M#{f1.call(x0 + r)} #{f1.call(y0)}H#{f1.call(x0 + W - r)}Q#{f1.call(x0 + W)} #{f1.call(y0)} #{f1.call(x0 + W)} #{f1.call(y0 + r)}" \
          "V#{f1.call(y0 + H - r)}Q#{f1.call(x0 + W)} #{f1.call(y0 + H)} #{f1.call(x0 + W - r)} #{f1.call(y0 + H)}H#{f1.call(x0 + r)}" \
          "Q#{f1.call(x0)} #{f1.call(y0 + H)} #{f1.call(x0)} #{f1.call(y0 + H - r)}V#{f1.call(y0 + r)}Q#{f1.call(x0)} #{f1.call(y0)} #{f1.call(x0 + r)} #{f1.call(y0)}Z"
      end
    end
  end
end
