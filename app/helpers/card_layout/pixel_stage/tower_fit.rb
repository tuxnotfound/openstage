module CardLayout
  class PixelStage
    # One day's tower at the narrowest width that fits under its callout,
    # with its flag, mast or the player placed. The player stands on the
    # week's biggest launch: the highest spot where both feet stand on blocks,
    # nothing pokes into the body, and the pole sits within reach of the hand.
    class TowerFit
      PW = 80 # the player, standing, with its outline
      PH = 92
      POLE_DX = 72
      POLE = 84

      def initialize(stage, per_row)
        @stage = stage
        @per_row = per_row
        @size = stage.block_size
      end

      # [fits, layout]: the narrowest layout that fits, else the widest tried.
      def lay(day, limit)
        n = day.units.size
        low, high = n.positive? ? [ [ @per_row, n ].min, [ 5, n ].min ] : [ 0, 0 ]
        layout = nil
        (low..high).each do |cols|
          layout = shape(day, n, cols)
          fits = props(day, layout, n, limit, cols == high)
          next if fits == :wider
          return [ true, layout ] if fits && roomy?(day, layout, n, limit)
        end
        [ false, layout ]
      end

      private

      def shape(day, n, cols)
        rows = n.positive? ? (n / cols.to_f).ceil : 0
        k = n.positive? && rows > 1 ? n % cols : 0
        tw = cols * @size
        { cols: cols, rows: rows, k: k, tw: tw, heights: heights(cols, rows, k, false), mirror: false, top: GY - (rows * @size),
          left: @stage.snap(day.cx - (tw / 2.0)), pole: nil, mast: nil, player: nil }
      end

      # The partial top row sits on the left; on the launch tower it may sit
      # right, by the pole.
      def heights(cols, rows, k, mirror)
        Array.new(cols) { |c| k.positive? && (mirror ? c < cols - k : c >= k) ? rows - 1 : rows }
      end

      def props(day, layout, n, limit, widest)
        fits = true
        if day == @stage.hero_day
          fits = hero(day, layout, n, limit, widest)
          return :wider if fits == :wider
        elsif day.shipped?
          fits = flag(layout, n, day, limit)
        end
        day.posted? ? mast(day, layout, n, limit) && fits : fits
      end

      def roomy?(day, layout, n, limit)
        return false if !day.shipped? && !day.posted? && day.box && n.positive? && layout[:top] - 16 < limit

        !(day.box.nil? && n.positive? && layout[:top] < 112)
      end

      # A narrow tower may slide right so the player can stand beside it.
      def hero(day, layout, n, limit, widest)
        mirrors = layout[:k].positive? ? [ false, true ] : [ false ]
        shifts = layout[:tw] < 64 ? [ 0, 16, 32, 48 ] : [ 0 ]
        spots = mirrors.product(shifts).filter_map do |mirror, shift|
          spot = spot(day, layout.merge(heights: heights(layout[:cols], layout[:rows], layout[:k], mirror), left: layout[:left] + shift), limit)
          spot&.merge(left: layout[:left] + shift, mirror: mirror)
        end
        best = spots.min_by { |spot| spot[:score] }
        return stand(layout, best) if best
        return :wider unless widest

        beside(day, layout, n, limit)
      end

      def stand(layout, spot)
        layout.merge!(left: spot[:left], player: spot[:player], pole: spot[:pole], mirror: spot[:mirror],
                      heights: heights(layout[:cols], layout[:rows], layout[:k], spot[:mirror]))
        true
      end

      # On the grass beside the tower, the pole planted on a stone at the
      # player's hand; the pennant flies over the tower, so it stays under it.
      def beside(day, layout, n, limit)
        width = PW + (n.positive? ? layout[:tw] + 4 : 0)
        left = @stage.snap(day.cx - (width / 2.0))
        layout.merge!(player: { x: left, y: GY - PH }, left: left + PW + 4, pole: { x: left + POLE_DX, base: GY - 8, top: GY - PH - 8, stone: true })
        GY - PH - 16 >= limit && !(n.positive? && layout[:top] < GY - PH + 32)
      end

      def flag(layout, n, day, limit)
        base = n.positive? ? layout[:top] : GY - 8
        x = n.positive? ? layout[:left] + 8 : @stage.snap(day.cx - 2)
        height = [ POLE, base - 8 - limit ].min
        layout[:pole] = { x: x, base: base, top: base - [ height, 64 ].max, stone: n.zero? }
        height >= 64
      end

      # The mast stands on the tower's top row, or on a stone without blocks.
      def mast(day, layout, n, limit)
        cell = @stage.cell2
        s = cell / P
        surface = layout[:k].positive? ? [ layout[:left], layout[:left] + (layout[:k] * @size) ] : [ layout[:left], layout[:left] + layout[:tw] ]
        base = n.positive? ? layout[:top] : GY - (3 * cell)
        x = n.positive? ? @stage.snap((surface.sum / 2.0) - (s * 2)) : @stage.snap(day.cx - (s * 2))
        height = [ 13 * cell, base - (5 * cell) - limit ].min
        layout[:mast] = { x: x, base: base, h: [ height, 32 ].max, stone: n.zero?, s: s }
        height >= 32
      end

      def spot(day, layout, limit)
        top_at = ->(x) { GY - height_at(layout, day.units.size, x) }
        surfaces = (layout[:heights].map { |h| GY - (h * @size) } + [ GY ]).uniq.sort
        candidates = surfaces.flat_map do |surface|
          ((layout[:left] - PW - 8)..(layout[:left] + layout[:tw])).step(P).filter_map { |x| spot_at(day, layout, x, surface, limit, top_at) }
        end
        candidates.min_by.with_index { |spot, i| [ spot[:score], i ] }
      end

      def height_at(layout, n, x)
        col = ((x - layout[:left]) / @size.to_f).floor
        n.positive? && col >= 0 && col < layout[:cols] && x >= layout[:left] ? layout[:heights][col] * @size : 0
      end

      # Both feet on blocks of this height, nothing taller under the legs, at
      # most one 24px step under the arms, and the pole on the highest block
      # under it, at most 24px above the feet.
      def spot_at(day, layout, x, surface, limit, top_at)
        return unless footing?(x, surface, top_at)

        base = (x + POLE_DX...x + POLE_DX + 6).step(2).map { |qx| top_at.call(qx) }.push(GY).min
        return if base < surface - 24 || (base == GY && surface != GY) || surface - PH - 16 < limit

        group(day, layout, x, surface, base)
      end

      def footing?(x, surface, top_at)
        (x + 16...x + 56).step(P).all? { |fx| top_at.call(fx) == surface } &&
          (x + 8...x + 64).step(P).none? { |bx| top_at.call(bx) < surface } &&
          [ x, x + 4, x + 64, x + 68 ].none? { |bx| top_at.call(bx) < surface - 24 }
      end

      # On the grass, the whole group stays in the day's column.
      def group(day, layout, x, surface, base)
        n = day.units.size
        from = [ x, n.positive? ? layout[:left] : x ].min
        to = [ x + PW, n.positive? ? layout[:left] + layout[:tw] : x + PW, x + POLE_DX + 52 ].max
        return if from < day.zx - 12 || to > day.zx + 150 + 24

        { score: (surface * 10) + ((from + to) / 2.0 - day.cx).abs, player: { x: x, y: surface - PH },
          pole: { x: x + POLE_DX, base: base, top: surface - PH - 8, stone: base == GY } }
      end
    end
  end
end
