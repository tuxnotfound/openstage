module CardLayout
  class PixelStage
    # A rest day's camp: a campfire with its warm light and smoke, or a tent
    # with a small fire beside it.
    class Camp
      def initialize(stage)
        @stage = stage
        @smoke = stage.dark ? "#C9C3D8" : "#FFFFFF"
      end

      def fire(cx, s)
        glow(cx, s)
        @stage.bitmap(:props, Sprites::CAMPFIRE, cx - (18 * s), GY - (36 * s), Sprites::FIRE, P * s)
        @stage.put(:props, "#FFB020", rect(cx - (28 * s), GY - P, 56 * s, P), 0.25)
        [ [ 0, -48, 0.32 ], [ 4, -60, 0.22 ], [ 0, -72, 0.14 ], [ 4, -84, 0.08 ] ].each do |dx, dy, o|
          @stage.put(:props, @smoke, rect(cx - (2 * s) + (dx * s), GY + (dy * s), P * s, P * s), o)
        end
      end

      # Firelight: a warm pool on the grass and a few sparks above the flames.
      # A translucent disc on a navy sky only turns grey.
      def glow(cx, s)
        @stage.put(:ground, "#FFD27A", rect(cx - (40 * s), GY, 80 * s, P), @stage.dark ? 0.55 : 0.6)
        @stage.put(:ground, "#FFB347", rect(cx - (28 * s), GY + P, 56 * s, 2 * P), @stage.dark ? 0.35 : 0.3)
        @stage.put(:fx, "#FFE27A", rect(cx - (12 * s), GY - (44 * s), P, P) + rect(cx + (10 * s), GY - (52 * s), P, P), 0.9)
        @stage.put(:fx, "#FFB020", rect(cx + (2 * s), GY - (60 * s), P, P), 0.7)
      end

      def tent(day, s)
        width = 52 * s
        x = @stage.snap(day.cx - (@stage.thin? ? 64 : 40))
        glow(@stage.snap(x + width + 14), 1)
        @stage.bitmap(:props, Sprites::TENT, x, GY - (28 * s), { "t" => "#E0603F", "T" => "#A8402C", "d" => "#1E1424" }, P * s)
        @stage.bitmap(:props, Sprites::SMALLFIRE, x + width + 4, GY - 20, Sprites::FIRE)
        [ [ 0, -32, 0.28 ], [ 4, -44, 0.18 ], [ 0, -56, 0.1 ] ].each do |dx, dy, o|
          @stage.put(:props, @smoke, rect(x + width + 16 + dx, GY + dy, P, P), o)
        end
        @stage.block(x, GY - (28 * s), width + 32, 28 * s, 0)
      end

      private

      def rect(*box) = @stage.rect(*box)
    end
  end
end
