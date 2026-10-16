module CardLayout
  class PixelStage
    # The stage door to next week: a little theatre with its curtain drawn,
    # the stage lit behind it, and next week's number on the marquee.
    class Door
      X = 1072
      W = 116
      Y = 404
      TOP = Y - 52
      GOLD = "#FFCB2E".freeze
      GOLD_LO = "#C98B4E".freeze

      def initialize(stage)
        @stage = stage
        @frame = stage.dark ? [ "#3A2346", "#5C3B6A", "#24142E" ] : [ "#5B3A63", "#7E5A88", "#3F2647" ]
      end

      def draw
        frame
        stage_light
        curtains
        valance
        marquee
        @stage.put(:ground, "#FFE29A", rect(X - 8, GY, W + 16, P), 0.6)
        @stage.put(:ground, "#FFC65C", rect(X + 8, GY + P, W - 16, 2 * P), 0.35)
        labels
        @stage.block(X - 8, TOP - 28, W + 16, GY - TOP + 28, 0)
      end

      private

      def rect(*box) = @stage.rect(*box)
      def gate(fill, d) = @stage.put(:gate, fill, d)

      def frame
        gate(@frame[0], rect(X, Y, W, GY - Y))
        gate(@frame[1], rect(X + P, Y + P, P, GY - Y - P) + rect(X + W - (4 * P), Y + (4 * P), P, GY - Y - (4 * P)))
        gate(@frame[2], rect(X + W - P, Y, P, GY - Y))
        gate(GOLD, rect(X, Y, W, P))
        gate(GOLD_LO, rect(X, Y + (3 * P), W, P))
      end

      def opening
        [ X + 16, W - 32, Y + 16 ]
      end

      # Warm at the top, bright on the boards.
      def stage_light
        left, width, top = opening
        lit = %w[#F29A45 #FFB65C #FFCC73 #FFDD94 #FFEBB8 #FFF6DC]
        band = ((GY - top) / lit.size.to_f / P).ceil * P
        lit.each_with_index { |color, i| gate(color, rect(left, top + (i * band), width, [ band, GY - top - (i * band) ].min)) }
      end

      # Straight, gathered at the tie-backs, a little flare at the boards.
      def curtains
        left, width, top = opening
        (top...(GY - 8)).step(P) do |y|
          t = (y - top) / (GY - 8 - top).to_f
          w = if t > 0.42 && t < 0.56 then 16
          elsif t >= 0.8 then @stage.snap(20 + (10 * (t - 0.8) / 0.2))
          else 20
          end
          gate("#C0283F", rect(left, y, w, P) + rect(left + width - w, y, w, P))
          gate("#8C1A2E", rect(left + 8, y, P, P) + rect(left + width - 12, y, P, P) + rect(left + w - P, y, P, P) + rect(left + width - w, y, P, P))
          gate("#E04A5E", rect(left + P, y, P, P) + rect(left + width - w + P, y, P, P))
        end
        tie = @stage.snap(top + (0.47 * (GY - 8 - top)))
        gate(GOLD, rect(left, tie, 20, 2 * P) + rect(left + width - 20, tie, 20, 2 * P))
      end

      # Scalloped, with a gold fringe; then the boards and footlights.
      def valance
        left, width, top = opening
        gate("#A61F36", rect(left, top, width, 12))
        gate("#A61F36", (left...(left + width)).step(12).map { |x| rect(x, top + 12, 8, P) }.join)
        gate(GOLD, ((left + P)...(left + width)).step(12).map { |x| rect(x, top + 16, P, P) }.join)
        gate("#8A5A2E", rect(left - 8, GY - 8, width + 16, 8))
        gate("#C98B4E", rect(left - 8, GY - 8, width + 16, P))
        gate("#FFF3B0", (left...(left + width)).step(12).map { |x| rect(x + 4, GY - 12, P, P) }.join)
      end

      def marquee
        x, w, y, h = X + 12, W - 24, TOP, 40
        gate("#03040E", @stage.notch(x - P, y - P, w + (2 * P), h + (2 * P)))
        gate("#2A1636", rect(x, y, w, h))
        bulbs(x, w, y, h)
        gate(@frame[2], rect(x + 16, y + h + P, P, Y - y - h - P) + rect(x + w - 20, y + h + P, P, Y - y - h - P))
      end

      # Every other bulb lit, around the sign.
      def bulbs(x, w, y, h)
        on, off = +"", +""
        count = 0
        ((x + 4)...(x + w - 4)).step(8) do |bx|
          ((count % 2).zero? ? on : off) << rect(bx, y + 4, P, P) << rect(bx, y + h - 8, P, P)
          count += 1
        end
        ((y + 12)...(y + h - 8)).step(8) do |by|
          ((count % 2).zero? ? off : on) << rect(x + 4, by, P, P) << rect(x + w - 8, by, P, P)
          count += 1
        end
        gate("#FFE27A", on)
        gate("#FF9E3D", off)
      end

      def labels
        next_week = (@stage.card.week_card.week_start + 7).cweek
        @stage.text("W#{next_week}", x: X + 12, y: TOP + 12, w: W - 24, align: "center", size: 16, shadow: @stage.hard_shadow(16, "#B3283E"))
        ink, shade = @stage.sky_ink(TOP - 20)
        @stage.text("NEXT STAGE", x: X - 24, y: TOP - 20, w: W + 48, align: "center", size: 8, color: @stage.dark ? "#FFE7C2" : ink,
                                  shadow: shade && @stage.hard_shadow(8, shade))
      end
    end
  end
end
