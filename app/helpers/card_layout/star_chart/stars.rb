module CardLayout
  class StarChart
    # What shines in the disc. A star is one hour of one project on one day:
    # on that day's ring, in the middle of that hour, sized and lit by its
    # commits. A launch is a nova, a post a comet, and every earlier commit a
    # grain of dust at its weekday and hour.
    class Stars
      SLOTS = 8
      # Above this many earlier commits one dot stands for several, so the
      # file stays small; the key says so.
      DUST_MAX = 1500
      Star = Data.define(:x, :y, :r, :day)

      attr_reader :list, :halos, :cores, :centers, :novas, :comets, :dust, :dust_count, :dust_step

      def initialize(chart)
        @chart = chart
        @halos = Array.new(SLOTS) { +"" }
        @cores = Array.new(SLOTS) { +"" }
        @centers = +""
        @list = []
        @last = {}
        chart.days.each { |day| stars_of(day) }
        @novas = chart.days.select { |day| day.kind == "shipped" }.filter_map { |day| day.launch ? chart.at(chart.ring(day.index), day.launch) : @last[day.index] }
        @comets = Comets.new(chart, list, novas).comets
        dust_of
      end

      # The four layers of every nova: a bloom, a glow, a ring, a flare, the
      # star and its core.
      def nova
        @nova ||= novas.each_with_object(Hash.new { |hash, key| hash[key] = +"" }) do |(x, y), paths|
          { bloom: 23, glow: 14, ring: 9, core: 2.3 }.each { |layer, r| paths[layer] << StarChart.circle(x, y, r) }
          paths[:flare] << "M#{f1(x - 28)} #{f1(y)}H#{f1(x + 28)}M#{f1(x)} #{f1(y - 28)}V#{f1(y + 28)}"
          paths[:star] << star_path(x, y)
        end
      end

      private

      def f1(value)
        StarChart.f1(value)
      end

      # Projects that share an hour on one day sit side by side along the
      # ring, so each stays on its day.
      def stars_of(day)
        radius = @chart.ring(day.index)
        step = [ 0.42, (10 / (2 * Math::PI * radius)) * 24 ].min
        groups = day.hours.flat_map do |hour, projects|
          sorted = projects.sort_by { |name, _n| @chart.projects.index { |project| project.name == name } || 0 }
          sorted.each_with_index.map { |(name, n), j| [ hour + 0.5 + ((j - ((sorted.size - 1) / 2.0)) * step), name, n ] }
        end
        groups.sort_by(&:first).each { |at, name, n| star(day, radius, at, name, n) }
      end

      def star(day, radius, at, name, count)
        x, y = @chart.at(radius, at)
        r = 1.3 + (1.9 * Math.sqrt(count))
        slot = @chart.slot(name)
        @halos[slot] << StarChart.circle(x, y, r * 2.4)
        @cores[slot] << StarChart.circle(x, y, r)
        @centers << StarChart.circle(x, y, [ 0.9, r * 0.42 ].max)
        @list << Star.new(x: x, y: y, r: r, day: day.index)
        @last[day.index] = [ x, y ]
      end

      def star_path(x, y)
        long, wide = 18, 2.2
        points = [ [ 0, -long ], [ wide, -wide ], [ long, 0 ], [ wide, wide ], [ 0, long ], [ -wide, wide ], [ -long, 0 ], [ -wide, -wide ] ]
        "M#{points.map { |dx, dy| "#{f1(x + dx)} #{f1(y + dy)}" }.join('L')}Z"
      end

      # Each earlier commit on its weekday's ring at its hour, with a minute
      # and a little radial jitter of its own: within 9px, under half the gap
      # between rings, so a dot never reads as the next day.
      def dust_of
        buckets = @chart.shows?("history") ? @chart.card.history.dust.sort : []
        @dust_count = buckets.sum(&:last)
        @dust_step = @dust_count > DUST_MAX ? (@dust_count / DUST_MAX.to_f).ceil : 1
        random = Random.new(Zlib.crc32("history|#{@chart.card.user.username}"))
        grains = buckets.flat_map { |(weekday, hour), count| Array.new(count) { grain(random, weekday, hour) } }
        @dust = grains.each_slice(@dust_step).map { |slice| StarChart.circle(*slice.first) }.join
      end

      def grain(random, weekday, hour)
        at = hour + random.rand
        radius = @chart.ring(weekday - 1) + ((random.rand - 0.5) * 18)
        [ *@chart.at(radius, at), 0.5 + (random.rand * random.rand) ]
      end
    end
  end
end
