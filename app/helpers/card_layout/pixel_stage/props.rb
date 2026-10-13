module CardLayout
  class PixelStage
    # What stands on the level besides the towers: a flag for each launch, a
    # broadcast mast for each post, a signpost for a built day without
    # commits, a campfire or a tent on each rest day, and the stage door to
    # next week. Each one marks its place, so later marks keep clear of it.
    class Props
      def initialize(stage)
        @stage = stage
        @dark = stage.dark
        @pole = @dark ? "#D9DCEB" : "#F4F5FA"
        @pole_shade = @dark ? "#8C90AC" : "#9AA0BE"
        @stone = @dark ? [ "#5C5F7E", "#7C80A0", "#3E405A" ] : [ "#8D90AE", "#B3B6CF", "#6B6E8C" ]
      end

      def draw
        @stage.obstacles << { x: 0, y: 0, w: 1200, h: 100 }
        @stage.block(1098, 86, 52, 52, 4) if @stage.sky[:moon]
        @stage.block(1076, 100, 64, 64, 4) if @stage.kind == :day && @stage.sky[:sun]
        @stage.days.each { |day| props(day) }
        touched_grass
        Door.new(@stage).draw
      end

      private

      def rect(*box) = @stage.rect(*box)
      def put(*args) = @stage.put(:props, *args)

      def props(day)
        @stage.block(day.left, day.top, day.tw, GY - day.top, 4) if day.units.any?
        @stage.block(day.box[:x], day.box[:y], day.box[:w], day.box[:h], 8) if day.box
        marks(day)
        tail(day) if day.box && day.target
        rest(day) if day.rest? && day != @stage.fire_day
      end

      # What the day's callout points at: its flag, its mast, a signpost, or
      # the top of its tower.
      def marks(day)
        flag(day) if day.pole
        mast(day) if day.mast
        signpost(day) if day.has? && day.total.zero? && !day.posted? && !day.shipped?
        day.target ||= tower_top(day) if day.units.any?
      end

      def flag(day)
        pole = day.pole
        if pole[:stone]
          put(@stone[0], rect(pole[:x] - 8, GY - 8, 20, 8))
          put(@stone[1], rect(pole[:x] - 8, GY - 8, 20, P))
        end
        height = pole[:base] - pole[:top]
        put(@pole, rect(pole[:x], pole[:top], P, height))
        put(@pole_shade, rect(pole[:x] + P, pole[:top], 2, height))
        put("#FFD54A", rect(pole[:x] - P, pole[:top] - (2 * P), 3 * P, 2 * P))
        put("#FFF3B0", rect(pole[:x] - P, pole[:top] - (2 * P), P, P))
        @stage.bitmap(:props, Sprites::PENNANT, pole[:x] + P, pole[:top] + P, { "f" => "#FFCB2E", "F" => "#E0950F", "w" => "#FFFFFF" })
        day.pennant = { x: pole[:x] + P, y: pole[:top] + P }
        day.target = { x: pole[:x], y: pole[:top] - (2 * P) }
        @stage.block(pole[:x] - P, pole[:top] - (2 * P), 52, height + (2 * P), 4)
      end

      def mast(day)
        mast = day.mast
        s, cell = mast[:s], P * mast[:s]
        top = mast[:base] - mast[:h]
        footing(mast, cell, s) if mast[:stone]
        put(@pole, rect(mast[:x], top, cell, mast[:h]))
        put(@pole_shade, rect(mast[:x] + cell, top, 2 * s, mast[:h]))
        put("#FF4D4D", rect(mast[:x] - cell, top - (2 * cell), 3 * cell, 2 * cell))
        put("#FFB3B3", rect(mast[:x] - cell, top - (2 * cell), cell, cell))
        waves(mast[:x], top, cell)
        day.target ||= { x: mast[:x], y: top - (4 * cell) - 4 }
        @stage.block(mast[:x] - (7 * cell), top - (4 * cell), 17 * cell, mast[:h] + (4 * cell), 4)
      end

      def footing(mast, cell, s)
        put(@stone[0], rect(mast[:x] - (3 * cell), mast[:base], (7 * cell) + (2 * s), 3 * cell))
        put(@stone[1], rect(mast[:x] - (3 * cell), mast[:base], (7 * cell) + (2 * s), cell))
        put(@stone[2], rect(mast[:x] - (3 * cell), mast[:base] + (2 * cell), (7 * cell) + (2 * s), cell))
      end

      # Two concentric arcs a side; on light skies they get a pale halo so they
      # read on lavender hills.
      def waves(x, top, cell)
        inner, outer = +"", +""
        width = Sprites::WAVE.first.length
        Sprites::WAVE.each_with_index do |row, j|
          row.each_char.with_index do |char, i|
            next if char == "."

            y = top - (4 * cell) + (j * cell)
            cells = rect(x - cell - ((width - i) * cell), y, cell, cell) + rect(x + (2 * cell) + ((width - 1 - i) * cell) + cell, y, cell, cell)
            (char == "i" ? inner : outer) << cells
          end
        end
        put("#FFFFFF", halo(inner + outer), 0.7) unless @dark
        put(@dark ? "#7FD4FF" : "#1D7FC4", inner)
        put(@dark ? "#7FD4FF" : "#1D7FC4", outer, 0.75)
      end

      def halo(path)
        path.gsub(/M(-?\d+) (-?\d+)h(\d+)v(\d+)h-?\d+z/) { rect(::Regexp.last_match(1).to_i - P, ::Regexp.last_match(2).to_i - P, ::Regexp.last_match(3).to_i + (2 * P), ::Regexp.last_match(4).to_i + (2 * P)) }
      end

      # A built day with no commits: a signpost on the empty lot, so its
      # callout has something to point at.
      def signpost(day)
        x = @stage.snap(day.cx - 2)
        put("#7A4A2A", rect(x, GY - 44, P, 44))
        put("#C98B4E", rect(x - 16, GY - 52, 36, 16))
        put("#8A5A2E", rect(x - 16, GY - 40, 36, P))
        put("#6B4423", rect(x - 12, GY - 48, 28, P))
        day.target = { x: x, y: GY - 52 }
        @stage.block(x - 16, GY - 52, 36, 52, 4)
      end

      def tower_top(day)
        middle = if day.k.zero? then day.tw / 2.0
        elsif day.mirror then day.tw - (day.k * @stage.block_size / 2.0)
        else day.k * @stage.block_size / 2.0
        end
        { x: @stage.snap(day.left + middle - 2), y: day.top }
      end

      def tail(day)
        day.tail = { x: day.target[:x], y0: day.box[:y] + day.box[:h] + 8, y1: day.target[:y] - 8 }
        @stage.block(day.tail[:x], day.tail[:y0], P, [ 0, day.tail[:y1] - day.tail[:y0] ].max, 4)
      end

      # A campfire, or on some days a tent with a small fire.
      def rest(day)
        s = @stage.cell2 / P
        return Camp.new(@stage).tent(day, s) if day.date.day % 4 == 3

        Camp.new(@stage).fire(day.cx, s)
        @stage.block(day.cx - (22 * s), GY - (40 * s), 44 * s, 40 * s, 0)
      end

      # Said out loud on weeks with three rest days or more: a plank sign by
      # the first fire.
      def touched_grass
        rests = @stage.days.select(&:rest?)
        return if rests.size < 3

        first = rests.find { |day| day != @stage.fire_day } || rests.first
        w, h = 148, 60
        x, y = @stage.snap(first.zx + 75 - (w / 2.0)), @stage.snap(GY - (@stage.thin? ? 80 : 44) - 24 - h)
        gate = ->(fill, d) { @stage.put(:gate, fill, d) }
        gate.call("#5A3320", rect(x + 20, y + h, 8, GY - y - h) + rect(x + w - 28, y + h, 8, GY - y - h))
        gate.call("#03040E", @stage.notch(x - P, y - P, w + (2 * P), h + (2 * P)))
        gate.call("#C98B4E", rect(x, y, w, h))
        gate.call("#8A5A2E", rect(x, y + h - P, w, P) + rect(x, y + 28, w, P))
        gate.call("#E0A86A", rect(x, y, w, P))
        @stage.text("TOUCHED", x: x, y: y + 8, w: w, align: "center", size: 16, shadow: @stage.hard_shadow(16, "#6B4423"))
        @stage.text("GRASS ×#{rests.size}", x: x, y: y + 36, w: w, align: "center", size: 16, shadow: @stage.hard_shadow(16, "#6B4423"))
        @stage.block(x - 8, y - 8, w + 16, GY - y + 8, 0)
      end
    end
  end
end
