module CardLayout
  class StarChart
    # The disc itself: a ring per day (a faint solid ring for a day with work,
    # a dashed one for a quiet day), the horizon, the day half above it and the
    # night half below, hour ticks on the rim, a sun above noon and a crescent
    # below midnight, and the window an hour persona is read from, in gold.
    class Sky
      Label = Data.define(:text, :x, :y, :anchor)

      attr_reader :rings_on, :rings_off, :ticks, :arc, :moon, :sun, :hour_labels

      # hours: the persona's window, [from, to) past 24, or nil.
      def initialize(chart, hours)
        @chart = chart
        @rings_on = chart.days.select(&:active?).map { |day| StarChart.circle(C[:x], C[:y], chart.ring(day.index)) }.join
        @rings_off = chart.days.reject(&:active?).map { |day| StarChart.circle(C[:x], C[:y], chart.ring(day.index)) }.join
        @ticks = ticks_of
        @arc = hours && arc_of(hours)
        @moon = moon_of
        @sun = sun_of
        @hour_labels = labels
      end

      def horizon
        "M#{C[:x] - C[:r2]} #{C[:y]}H#{C[:x] + C[:r2]}"
      end

      def night_half
        "M#{C[:x] - C[:r]} #{C[:y]}A#{C[:r]} #{C[:r]} 0 0 0 #{C[:x] + C[:r]} #{C[:y]}Z"
      end

      def day_half
        "M#{C[:x] - C[:r]} #{C[:y]}A#{C[:r]} #{C[:r]} 0 0 1 #{C[:x] + C[:r]} #{C[:y]}Z"
      end

      private

      def f1(value)
        StarChart.f1(value)
      end

      def line(a, b)
        "M#{f1(a[0])} #{f1(a[1])}L#{f1(b[0])} #{f1(b[1])}"
      end

      # Quarter hours, hours, and long marks at 00, 06, 12 and 18.
      def ticks_of
        (0...96).each_with_object({ minor: +"", hour: +"", major: +"" }) do |j, ticks|
          kind = if (j % 24).zero? then :major
          elsif (j % 4).zero? then :hour
          else :minor
          end
          length = { major: 12, hour: 6.5, minor: 2.5 }.fetch(kind)
          ticks[kind] << line(@chart.at(C[:r], j / 4.0), @chart.at(C[:r] + length, j / 4.0))
        end
      end

      # Lit between the two rims, with its ends marked and named, unless an
      # end falls on a labelled hour.
      def arc_of(hours)
        radius = (C[:r] + C[:r2]) / 2.0
        from, to = hours.map { |hour| @chart.at(radius, hour) }
        ends = hours.map { |hour| line(@chart.at(C[:r2] - 3, hour), @chart.at(C[:r] + 9, hour)) }.join
        names = hours.reject { |hour| ((hour % 24) % 6).zero? }.map do |hour|
          x, y = @chart.at(C[:r] + 22, hour)
          Label.new(text: format("%02dh", hour % 24), x: f1(x), y: f1(y + 3.7), anchor: "middle")
        end
        { d: "M#{f1(from[0])} #{f1(from[1])}A#{radius} #{radius} 0 #{hours.last - hours.first > 12 ? 1 : 0} 0 #{f1(to[0])} #{f1(to[1])}",
          ends: ends, labels: names }
      end

      def moon_of
        x, y = C[:x], C[:y] + C[:r] + 25
        outer, inner, ox, oy = 11.5, 9.8, 5.6, -3.4
        d = Math.hypot(ox, oy)
        a = ((outer**2) - (inner**2) + (d**2)) / (2 * d)
        h = Math.sqrt([ 0, (outer**2) - (a**2) ].max)
        ux, uy = ox / d, oy / d
        p1 = [ x + (ux * a) - (uy * h), y + (uy * a) + (ux * h) ]
        p2 = [ x + (ux * a) + (uy * h), y + (uy * a) - (ux * h) ]
        { d: "M#{f1(p1[0])} #{f1(p1[1])}A#{outer} #{outer} 0 1 1 #{f1(p2[0])} #{f1(p2[1])}A#{inner} #{inner} 0 1 0 #{f1(p1[0])} #{f1(p1[1])}Z",
          cx: f1(x), cy: f1(y), r: outer }
      end

      def sun_of
        x, y = C[:x], C[:y] - C[:r] - 25
        rays = (0...8).map do |k|
          angle = k * Math::PI / 4
          "M#{f1(x + (Math.cos(angle) * 8.4))} #{f1(y + (Math.sin(angle) * 8.4))}L#{f1(x + (Math.cos(angle) * 12))} #{f1(y + (Math.sin(angle) * 12))}"
        end
        { disc: StarChart.circle(x, y, 5.4), rays: rays.join }
      end

      def labels
        top, bottom = C[:y] - C[:r] - 25, C[:y] + C[:r] + 25
        [ Label.new(text: "00h", x: f1(C[:x] + 20), y: f1(bottom + 4.2), anchor: "start"),
          Label.new(text: "06h", x: f1(C[:x] + C[:r] + 34), y: f1(C[:y] + 4.2), anchor: "middle"),
          Label.new(text: "12h", x: f1(C[:x] + 20), y: f1(top + 4.2), anchor: "start"),
          Label.new(text: "18h", x: f1(C[:x] - C[:r] - 34), y: f1(C[:y] + 4.2), anchor: "middle") ]
      end
    end
  end
end
