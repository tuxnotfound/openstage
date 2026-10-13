module CardLayout
  class PixelStage
    # The player: on the launch tower with the flag, waving on the busiest
    # tower of a week without a launch, on a log by the last fire toasting a
    # marshmallow, or waving at the stage door. The hood takes the
    # colour of the launch day's top project. Every sprite gets a one-cell
    # outline on the 4-neighbourhood, so its corners stay notched. Launch weeks
    # get a pixel sunburst behind the player.
    class Player
      RAYS = 12

      def initialize(stage)
        @stage = stage
        @dark = stage.dark
        @outline = @dark ? "#03040E" : "#1B1F3B"
      end

      def draw
        case @stage.pose
        when :sit then sit
        when :idle then idle
        else stand
        end
      end

      private

      def rect(*box) = @stage.rect(*box)

      def palette
        hood = hood_color
        { "g" => "#F4F1EA", "G" => "#C9C2B4", "m" => "#FFFFFF", "a" => "#AEB6D6", "W" => "#FFFFFF", "q" => "#F4F1EA", "b" => "#8A5A2E",
          "B" => "#6B4422", "h" => hood, "H" => Paint.mix(hood, "#FFFFFF", 0.3), "s" => Paint.mix(hood, "#000000", 0.3),
          "S" => Paint.mix(hood, "#000000", 0.48), "p" => Paint.mix(hood, "#000000", 0.18), "w" => "#FFFFFF", "j" => "#34407E",
          "J" => "#252E60", "k" => "#F2F2F2", "K" => "#A9ADCB", "e" => "#B07A48", "E" => "#8A5A2E", "l" => "#7A4A2A", "L" => "#5A3320",
          "v" => @dark ? "#26305E" : "#1B2340", "V" => "#9AD7FF" }
      end

      def hood_color
        hero = @stage.hero_day
        top = hero && hero.counts.sort_by.with_index { |(name, n), i| [ -n, @stage.rank(name), i ] }.first
        return @stage.color_of(top.first) if top
        return @stage.color_of(@stage.projects.first.first) if @stage.projects.any?

        "#E85AAD"
      end

      def sprite(layer, rows, x, y)
        width = rows.map(&:length).max
        cells = (-1..rows.size).flat_map { |r| (-1..width).select { |c| outline?(rows, c, r) }.map { |c| rect(x + (c * P), y + (r * P), P, P) } }
        @stage.put(layer, @outline, cells.join)
        @stage.bitmap(layer, rows, x, y, palette)
      end

      # An empty cell beside a filled one, or a cell the sprite marks "o".
      def outline?(rows, c, r)
        return rows[r][c] == "o" if on?(rows, c, r)

        [ [ c - 1, r ], [ c + 1, r ], [ c, r - 1 ], [ c, r + 1 ] ].any? { |cc, rr| on?(rows, cc, rr) }
      end

      def on?(rows, c, r)
        r >= 0 && r < rows.size && c >= 0 && c < rows[r].length && rows[r][c] != "."
      end

      def stand
        launch = @stage.hero_day.shipped?
        player = @stage.hero_day.player
        sprite(:hero, launch ? Sprites::STAND : Sprites::IDLE, player[:x] + P, player[:y] + P)
        @stage.block(player[:x], player[:y], TowerFit::PW, TowerFit::PH, 4)
        sunburst(player) if launch
      end

      # Already on next week's stage, in front of the curtain.
      def idle
        player = { x: Door::X + (Door::W / 2) - 40, y: GY - TowerFit::PH - 4 }
        sprite(:hero, Sprites::IDLE, player[:x] + P, player[:y] + P)
        @stage.block(player[:x], player[:y], 72, TowerFit::PH, 4)
      end

      def sit
        s = @stage.cell2 / P
        fire_w = 36 * s
        group_w = 76 + fire_w
        left = @stage.snap(@stage.fire_day.cx - (group_w / 2.0))
        fire_x = left + 76 + (fire_w / 2.0)
        player = { x: left, y: GY - TowerFit::PH }
        Camp.new(@stage).fire(fire_x, s)
        sprite(:hero_back, Sprites::LOG, player[:x] - 4, GY - 20)
        sprite(:hero, Sprites::SIT, player[:x] + P, player[:y] + P)
        marshmallow(player, fire_x, s)
        @stage.block(player[:x] - 8, player[:y] - 4, group_w + 12, TowerFit::PH + 4, 4)
      end

      # The stick, from the right glove up toward the flames, and the
      # marshmallow on it.
      def marshmallow(player, fire_x, s)
        x, y = player[:x] + 76, player[:y] + 60
        to_x, to_y = @stage.snap(fire_x - (6 * s) - 8), @stage.snap(GY - (26 * s) - 8)
        stick = +""
        while x < to_x - P || y > to_y + P
          x += P if x < to_x - P
          y -= P if y > to_y + P && (y - to_y) >= (to_x - x)
          stick << rect(x, y, P, P)
        end
        @stage.put(:hero, "#8A5A2E", stick)
        @stage.put(:hero, @outline, rect(x, y - 8, 12, 12))
        @stage.put(:hero, "#FFF6E0", rect(x + 2, y - 6, 8, 8))
        @stage.put(:hero, "#E8B26A", rect(x + 2, y - 2, 8, P))
      end

      # Night skies in the dark theme keep only a warm disc behind the player.
      def sunburst(player)
        return if @stage.kind == :night && @dark

        cx, cy = player[:x] + 40, player[:y] + 32
        color = @dark ? "#FFF3B0" : "#FFFFFF"
        box = [ @stage.snap(cx - 168), [ 100, @stage.snap(cy - 168) ].max, @stage.snap(cx + 168), [ GY, @stage.snap(cy + 168) ].min ]
        @stage.put(:glow, color, @stage.disc(@stage.snap(cx), @stage.snap(cy), 52), @dark ? 0.1 : 0.22)
        @stage.put(:glow, color, raster(*box) { |x, y| ray?(x - cx, y - cy, 44, 108) }, @dark ? 0.12 : 0.3)
        @stage.put(:glow, color, raster(*box) { |x, y| ray?(x - cx, y - cy, 108, 168) }, @dark ? 0.06 : 0.16)
      end

      def ray?(dx, dy, from, to)
        distance = Math.hypot(dx, dy)
        return false if distance < from || distance >= to

        ((Math.atan2(dy, dx) + (2 * Math::PI) + 0.13) % (2 * Math::PI / RAYS)) < Math::PI / RAYS
      end

      # The cells of a box where the block holds, as runs of cells per row.
      def raster(x0, y0, x1, y1)
        (y0...y1).step(P).map do |y|
          runs = (x0..x1).step(P).map { |x| x < x1 && yield(x + 2, y + 2) }
          runs.each_with_index.chunk_while { |(a, _i), (b, _j)| a == b }.select { |run| run.first.first }
              .map { |run| rect(x0 + (run.first.last * P), y, run.size * P, P) }.join
        end.join
      end
    end
  end
end
