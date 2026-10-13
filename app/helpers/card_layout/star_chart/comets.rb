module CardLayout
  class StarChart
    # Each post is a comet: the head at the post's logged time on its day's
    # ring, the tail trailing back in time (counter-clockwise), as if it moved
    # with the clock. The tail leans outward, or inward when that crosses
    # fewer stars, and never leaves the disc or crosses the hub.
    class Comets
      # Lean (outward 1, inward -1) and tilt, in the order they are tried.
      LEANS = [ [ 1, 0.34 ], [ -1, 0.34 ], [ 1, 0.6 ], [ -1, 0.6 ] ].freeze
      Comet = Data.define(:head, :tail_end, :dust_end, :scale, :tail, :dust_tail, :head_path, :glow)

      attr_reader :comets

      def initialize(chart, stars, novas)
        @chart = chart
        @stars = stars
        @novas = novas
        timed = chart.days.select { |day| day.kind == "published" && day.post }
        @comets = timed.map { |day| comet(day, timed) }
      end

      private

      def f1(value)
        StarChart.f1(value)
      end

      # A lone post in a week without commits is drawn larger; comets that
      # share a quarter of the clock, smaller.
      def comet(day, timed)
        quarter = ->(hour) { (hour % 24).floor / 6 }
        crowd = timed.count { |other| quarter.call(other.post) == quarter.call(day.post) }
        k = (@chart.commits.zero? && timed.size == 1 ? 1.45 : 1) * (crowd > 1 ? 0.82 : 1)
        head = @chart.at(@chart.ring(day.index), day.post)
        tail_end, dust_end = tail(head, day.post, k)
        shape(head, tail_end, dust_end, k)
      end

      # The lean that crosses the fewest stars and novas.
      def tail(head, hour, k)
        angle = (hour / 24.0 * Math::PI * 2) - (Math::PI / 2)
        back = [ Math.sin(angle), -Math.cos(angle) ]
        out = [ Math.cos(angle), Math.sin(angle) ]
        tip = ->(length, tilt, lean) { [ 0, 1 ].map { |i| head[i] + (length * ((Math.cos(tilt) * back[i]) + (Math.sin(tilt) * lean * out[i]))) } }
        tried = LEANS.each_with_index.filter_map do |(lean, tilt), order|
          ends = [ tip.call(50 * k, tilt, lean), tip.call(60 * k, tilt + 0.24, lean) ]
          [ crossings(head, ends, order), ends ] if inside?(ends)
        end
        tried.min_by(&:first)&.last || [ tip.call(50 * k, 0.34, 1), tip.call(60 * k, 0.58, 1) ]
      end

      def inside?(ends)
        distances = ends.map { |x, y| Math.hypot(x - C[:x], y - C[:y]) }
        distances.max <= C[:r2] - 3 && distances.min >= C[:hub] + 14
      end

      def crossings(head, ends, order)
        near = ->(point, gap) { ends.any? { |tip| distance(head, tip, point) < gap } }
        (order * 0.3) + @stars.count { |star| near.call([ star.x, star.y ], (star.r * 2.4) + 2) } +
          (2 * @novas.count { |nova| near.call(nova, 22) })
      end

      # From a point to the segment a-b.
      def distance(a, b, point)
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = (dx**2) + (dy**2)
        u = ((((point[0] - a[0]) * dx) + ((point[1] - a[1]) * dy)) / (length.zero? ? 1 : length)).clamp(0, 1)
        Math.hypot(point[0] - (a[0] + (dx * u)), point[1] - (a[1] + (dy * u)))
      end

      # The ion tail and the wider dust tail, each a curved wedge from the head.
      def shape(head, tail_end, dust_end, k)
        scale = [ 1, k ].max
        Comet.new(head: head, tail_end: tail_end, dust_end: dust_end, scale: scale,
                  tail: wedge(head, tail_end, 4 * k, [ 3.4 * scale, 3 * k, 1.5 * k ]),
                  dust_tail: wedge(head, dust_end, 7 * k, [ 5 * k, 6 * k, 2 * k ], dust: true),
                  head_path: StarChart.circle(*head, 3.2 * scale), glow: StarChart.circle(*head, 8.5 * scale))
      end

      # bow: how far the wedge's middle bends; widths: at the head, and how far
      # each side's curve swings out.
      def wedge(head, tip, bow, widths, dust: false)
        length = Math.hypot(head[0] - tip[0], head[1] - tip[1])
        nx, ny = -(head[1] - tip[1]) / length, (head[0] - tip[0]) / length
        bx, by = ((head[0] + tip[0]) / 2) + (nx * bow), ((head[1] + tip[1]) / 2) + (ny * bow)
        start, out, back = widths
        finish = dust ? back : start
        "M#{f1(head[0] + (nx * start))} #{f1(head[1] + (ny * start))}Q#{f1(bx + (nx * out))} #{f1(by + (ny * out))} " \
          "#{f1(tip[0])} #{f1(tip[1])}Q#{f1(bx - (nx * back))} #{f1(by - (ny * back))} #{f1(head[0] - (nx * finish))} #{f1(head[1] - (ny * finish))}Z"
      end
    end
  end
end
