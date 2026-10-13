module CardLayout
  class PixelStage
    # The level's backdrop, back to front: the sky in bands, its stars, moon,
    # clouds or sun, two ridges of hills with pines, and the ground. The random
    # numbers are drawn in the mock's order, so the scene matches it.
    class Scenery
      BAND = 44

      def initialize(stage)
        @stage = stage
        @sky = stage.sky
        @ground = stage.ground
        @random = stage.random
      end

      def draw
        bands
        stars if @sky[:stars]
        moon if @sky[:moon]
        clouds if @sky[:cloud]
        hills
        ground
      end

      private

      def snap(value) = @stage.snap(value)
      def rect(*box) = @stage.rect(*box)
      def rand = @random.rand

      # A one-cell checker at each band edge, below the HUD so it never runs
      # behind small type.
      def bands
        colors = @sky[:bands]
        colors.each_with_index do |color, i|
          height = i == colors.size - 1 ? GY - (i * BAND) : BAND
          @stage.put(:sky, color, rect(0, i * BAND, 1200, height))
        end
        (1...colors.size).each do |i|
          y = i * BAND
          next if y < 104

          @stage.put(:dith, colors[i], (0...1200).step(2 * P).map { |x| rect(x, y - P, P, P) }.join)
          @stage.put(:dith, colors[i - 1], (0...1200).step(2 * P).map { |x| rect(x + P, y, P, P) }.join)
        end
      end

      # Fifty-six stars over the hills, fourteen in the HUD's gaps, and four
      # that twinkle.
      def stars
        56.times do
          x, y = snap(rand * 1196), snap(104 + (rand * 260))
          @stage.put(:deco, @sky[:stars], rect(x, y, P, P), rand > 0.5 ? 0.9 : 0.45)
        end
        hud_stars
        [ [ 176, 300 ], [ 520, 248 ], [ 760, 332 ], [ 1012, 272 ] ].each do |x, y|
          @stage.put(:deco, @sky[:stars], rect(x - P, y, 3 * P, P) + rect(x, y - P, P, 3 * P), 0.85)
        end
      end

      def hud_stars
        clear = [ [ 8, 4, 420, 100 ], [ 430, 4, 340, 84 ], [ 880, 4, 316, 72 ], [ 1060, 60, 100, 72 ] ]
        placed = 0
        80.times do
          break if placed >= 14

          x, y = snap(rand * 1196), snap(8 + (rand * 88))
          next if clear.any? { |ax, ay, aw, ah| x >= ax && x < ax + aw && y >= ay && y < ay + ah }

          @stage.put(:deco, @sky[:stars], rect(x, y, P, P), rand > 0.5 ? 0.8 : 0.4)
          placed += 1
        end
      end

      def moon
        x, y, r = 1124, 112, 22
        lit, dim = +"", +""
        (-r...r).step(P) do |dy|
          (-r...r).step(P) do |dx|
            next unless ((dx + 2)**2) + ((dy + 2)**2) <= r * r

            (((dx + 12)**2) + ((dy - 6)**2) <= (r - 4)**2 ? dim : lit) << rect(x + dx, y + dy, P, P)
          end
        end
        @stage.put(:deco, @sky[:moon], lit)
        @stage.put(:deco, @sky[:moon], dim, 0.12)
      end

      def clouds
        [ [ 88, 268, 1 ], [ 420, 300, 0.8 ], [ 880, 248, 1 ], [ 1040, 332, 0.7 ] ].each do |x, y, o|
          @stage.bitmap(:deco, Sprites::CLOUD, x, y, { "c" => @sky[:cloud] }, P, (0.55 * o).round(2))
        end
      end

      # Thin weeks raise the horizon to match their bigger props. The sun sets
      # between the two ridges, so half a disc shows above the near one.
      def hills
        far, near = @stage.thin? ? [ 364, 448 ] : [ 400, 470 ]
        phase = (Random.hash(@stage.card.user.username.to_s) % 100 / 10.0) + (@stage.card.week_card.week_start.cweek * 0.7)
        @stage.put(:far_hills, @sky[:far], ridge(far, 46, 0.006, phase, 16))
        sun if @sky[:sun]
        @stage.put(:hills, @sky[:near], ridge(near, 24, 0.011, phase * 1.85, 12))
        pines(near, phase * 1.85)
      end

      def ridge_y(x, base, amp, f, phase)
        snap(base + (amp * ((Math.sin((x * f) + phase) * 0.65) + (Math.sin((x * f * 2.7) + (phase * 1.9)) * 0.35))))
      end

      def ridge(base, amp, f, phase, step)
        "M0 #{GY}#{(0...1200).step(step).map { |x| "V#{ridge_y(x, base, amp, f, phase)}H#{x + step}" }.join}V#{GY}Z"
      end

      def sun
        x, y, r = { dusk: [ 872, 456, 64 ], dawn: [ 152, 460, 60 ] }.fetch(@stage.kind, [ 1108, 132, 28 ])
        outer, inner = +"", +""
        (-r...r).step(P) do |dy|
          half = snap(Math.sqrt([ 0, (r * r) - ((dy + 2)**2) ].max))
          outer << rect(x - half, y + dy, 2 * half, P)
          core = r - 14
          next unless (dy + 2).abs < core

          inner_half = snap(Math.sqrt((core * core) - ((dy + 2)**2)))
          inner << rect(x - inner_half, y + dy, 2 * inner_half, P)
        end
        stage = @stage.kind == :day ? :deco : :sun_layer
        @stage.put(stage, @sky[:sun], outer, 0.95)
        @stage.put(stage, @sky[:sun_in], inner)
      end

      def pines(base, phase)
        color = Paint.mix(@sky[:near], "#000000", @stage.dark ? 0.3 : 0.14)
        x = 8 + snap(rand * 40)
        while x < 1180
          at = (x / 12) * 12
          y = [ ridge_y(at, base, 24, 0.011, phase), ridge_y(at + 12, base, 24, 0.011, phase) ].min
          tall = rand > 0.5
          @stage.bitmap(:hills, tall ? Sprites::PINE : Sprites::PINE_S, x, y - (tall ? 20 : 12) + (rand > 0.5 ? 4 : 0), { "t" => color })
          x += 36 + snap(rand * 64)
        end
      end

      def ground
        @stage.put(:ground, @ground[:hi], rect(0, GY, 1200, P))
        @stage.put(:ground, @ground[:grass], rect(0, GY + P, 1200, 2 * P))
        @stage.put(:ground, @ground[:dirt], rect(0, GY + (3 * P), 1200, 630 - GY - (3 * P)))
        160.times do
          x, y = snap(rand * 1196), snap(GY + 16 + (rand * 96))
          color = rand > 0.5 ? @ground[:s1] : @ground[:s2]
          @stage.put(:ground, color, rect(x, y, P * (rand > 0.7 ? 2 : 1), P))
        end
        (0...1200).step(24) do |x|
          @stage.bitmap(:ground, Sprites::TUFT, x + snap(rand * 8), GY - (2 * P), { "g" => @ground[:tuft] }) if rand > 0.35
        end
      end
    end
  end
end
