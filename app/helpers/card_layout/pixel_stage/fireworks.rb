module CardLayout
  class PixelStage
    # Two bursts per launch, in clear sky by the pennant, in that day's
    # colours; they stay in the day's own column, plus 24px each side, unless
    # nothing fits there. Then a shooting star on night skies, and flowers in
    # the grass, away from everything already standing.
    class Fireworks
      DIRS = [ [ 1, 0 ], [ -1, 0 ], [ 0, 1 ], [ 0, -1 ], [ 1, 1 ], [ 1, -1 ], [ -1, 1 ], [ -1, -1 ] ].freeze
      KNIGHT = [ [ 2, 1 ], [ 1, 2 ], [ -1, 2 ], [ -2, 1 ], [ -2, -1 ], [ -1, -2 ], [ 1, -2 ], [ 2, -1 ] ].freeze
      SPARKS = [ [ 52, -12 ], [ -16, -4 ], [ 56, 28 ], [ -20, 24 ] ].freeze
      CANDIDATES = (-112..72).step(16).flat_map { |dy| (-176..176).step(16).filter_map { |dx| [ dx, dy ] if dx.abs >= 40 } }.freeze

      def initialize(stage)
        @stage = stage
        @dark = stage.dark
        @spark = @dark ? "#FFF3B0" : "#FFB020"
      end

      def draw
        @stage.days.each { |day| launch(day) if day.pennant }
        shooting_star if @stage.kind == :night
        flowers
      end

      private

      def rect(*box) = @stage.rect(*box)
      def fx(*args) = @stage.put(:fx, *args)

      def launch(day)
        colors = day.units.uniq
        colors << "#FFD54A" if colors.empty?
        colors << Paint.mix(colors.first, "#FFFFFF", 0.35) if colors.size < 2
        sparks(day.pennant)
        picked = []
        [ [ 28, 24, 20, 16 ], [ 24, 20, 16 ] ].each_with_index do |radii, i|
          best = place(day, radii, picked)
          next unless best

          burst(best[:cx], best[:cy], best[:r], colors[i % colors.size])
          picked << best
          @stage.obstacles << best[:box]
        end
      end

      # Two small sparks by the pennant, where nothing stands.
      def sparks(pennant)
        clear = SPARKS.select do |dx, dy|
          box = { x: pennant[:x] + dx - P, y: pennant[:y] + dy, w: 3 * P, h: 3 * P }
          next false if @stage.hit?(box)

          @stage.obstacles << box
          true
        end
        clear.first(2).each_with_index do |(dx, dy), i|
          x, y = pennant[:x] + dx, pennant[:y] + dy
          fx(@spark, rect(x, y, P, P) + rect(x - P, y + P, 3 * P, P) + rect(x, y + (2 * P), P, P), i.zero? ? 1 : 0.7)
        end
      end

      # The nearest clear spot, first in the day's column and on the other
      # side of the first burst; then anywhere.
      def place(day, radii, picked)
        center = { x: day.pennant[:x] + 22, y: day.pennant[:y] + 14 }
        [ [ true, true ], [ true, false ], [ false, true ], [ false, false ] ].each do |own, strict|
          best = nil
          radii.each do |r|
            CANDIDATES.each do |dx, dy|
              spot = spot(day, center, dx, dy, r, own, strict, picked)
              best = spot if spot && (best.nil? || spot[:score] < best[:score])
            end
          end
          return best if best
        end
        nil
      end

      def spot(day, center, dx, dy, r, own, strict, picked)
        cx, cy = @stage.snap(center[:x] + dx), @stage.snap(center[:y] + dy)
        box = { x: cx - r - 4, y: cy - r - 4, w: (2 * r) + 12, h: (2 * r) + 40 }
        return unless in_sky?(box) && (!own || in_column?(box, day)) && !@stage.hit?(box)
        return if strict && picked.any? && (dx <=> 0) == (picked.first[:dx] <=> 0)

        { dx: dx, cx: cx, cy: cy, box: box, r: r, score: Math.hypot(dx, dy * 1.3) + (dy > 8 ? 24 : 0) + ((28 - r) * 2) }
      end

      def in_sky?(box)
        box[:x] >= 8 && box[:x] + box[:w] <= 1192 && box[:y] >= 100 && box[:y] + box[:h] <= GY - 8
      end

      def in_column?(box, day)
        box[:x] >= day.zx - 24 && box[:x] + box[:w] <= day.zx + 150 + 24
      end

      # On light skies pale tips and translucent halos vanish, so the bursts
      # go darker at the tips instead.
      def burst(cx, cy, r, color)
        n = (r / P.to_f).round
        pale = Paint.mix(color, "#FFFFFF", @dark ? 0.5 : 0.25)
        tip = @dark ? "#FFF3B0" : Paint.mix(color, "#1B1F3B", 0.3)
        if @dark
          @stage.put(:fx_glow, color, @stage.disc(cx + 2, cy + 2, r + 8), 0.1)
          @stage.put(:fx_glow, color, @stage.disc(cx + 2, cy + 2, @stage.snap(r * 0.6)), 0.12)
        end
        rays(cx, cy, n, color, pale, tip)
        fx(@dark ? "#FFFFFF" : "#FFD54A", rect(cx, cy, P, P))
        fx(@spark, rect(cx - P, cy, P, P) + rect(cx + P, cy, P, P) + rect(cx, cy - P, P, P) + rect(cx, cy + P, P, P), 0.8)
        [ 0.55, 0.35, 0.2 ].each_with_index { |o, k| fx(@dark ? pale : color, rect(cx, cy + ((n + 3 + (2 * k)) * P), P, P), o) }
      end

      # Eight straight rays, shorter on the diagonals, pale near the core.
      def rays(cx, cy, n, color, pale, tip)
        DIRS.each do |dx, dy|
          length = dx.nonzero? && dy.nonzero? ? (n * 0.72).round : n
          (2..length).each { |k| fx(ray_color(k, length, color, pale, tip), rect(cx + (dx * k * P), cy + (dy * k * P), P, P)) }
        end
        knights(cx, cy, n, color, tip)
      end

      def ray_color(k, length, color, pale, tip)
        return tip if k == length

        k <= 3 ? pale : color
      end

      # Eight short spokes between the rays, a knight's move apart.
      def knights(cx, cy, n, color, tip)
        m = n >= 6 ? 3 : 2
        KNIGHT.each do |dx, dy|
          (1..m).each { |t| fx(t == m ? tip : color, rect(cx + (dx * t * P), cy + (dy * t * P), P, P), t == m ? 0.7 : 0.85) }
        end
      end

      # Where the sky is clear.
      def shooting_star
        [ [ 652, 232 ], [ 300, 264 ], [ 856, 204 ], [ 420, 196 ], [ 176, 236 ], [ 760, 280 ] ].each do |x, y|
          next if @stage.hit?({ x: x - 28, y: y - 28, w: 36, h: 36 })

          6.times { |k| @stage.put(:deco, "#FFFFFF", rect(x - (k * P), y - (k * P), P, P), (1 - (k * 0.15)).round(2)) }
          @stage.put(:deco, "#FFFFFF", rect(x + P, y, P, P) + rect(x, y + P, P, P), 0.35)
          break
        end
      end

      def flowers
        colors = @dark ? %w[#FF8FB1 #FFE27A #E9E6F2] : %w[#FF6F9C #FFD23F #FFFFFF]
        18.times do |i|
          x = @stage.snap(16 + (@stage.random.rand * 1040))
          next if @stage.hit?({ x: x - 4, y: GY - 12, w: 12, h: 12 })

          @stage.put(:ground, @stage.ground[:tuft], rect(x, GY - P, P, P))
          @stage.put(:ground, colors[i % 3], rect(x, GY - (2 * P), P, P))
        end
      end
    end
  end
end
