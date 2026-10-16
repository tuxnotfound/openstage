module CardLayout
  class Journey
    # The builder's words on flags along the ink line, ported from the Journey
    # engine. Entries are tried in order (pins, what the builder swapped in,
    # then the pick's rank), one flag per circle, until the period's cap. A
    # flag stays inside the plot, 3px clear above the line, 6px from other
    # flags, poles and circles, clear of the end label, and its pole never
    # crosses another flag. A circle whose first entry fits nowhere stays bare.
    class Flags
      LOW = 282
      HIGH = 548
      MEASURE = 290
      SIZE = 20
      LEADING = 24
      GAP = 10
      RISES = [ 8, 28, 48, 68 ].freeze
      CAPS = { "week" => 3, "month" => 4, "year" => 6, "all" => 6 }.freeze
      HALO = 3
      RADIUS = 7.5
      END_DOT = 5
      END_PAD = 72
      FACES = { 600 => :inter_semibold, 500 => :inter_medium, 400 => :inter_regular }.freeze

      Shape = Data.define(:lines, :run, :w, :h)
      Box = Data.define(:x, :y, :w, :h, :kind, :marker)
      Flag = Data.define(:marker, :item, :shape, :side, :x, :y, :pole_x, :pole_top, :pole_bottom) do
        def weight
          Flags.weight(item)
        end
      end

      attr_reader :all

      def self.weight(item)
        if item.pinned? then 600
        elsif item.shipped? then 500
        else 400
        end
      end

      def initialize(geometry, section)
        @geometry = geometry
        @section = section
        @names = section.tally.projects.all.map(&:name)
        @obstacles = obstacles
        @all = place_all
      end

      private

      def place_all
        flags = []
        tried = []
        order.each do |item, swapped|
          marker = @geometry.markers.find { |candidate| candidate.items.include?(item) }
          next if marker.nil? || tried.include?(marker) || flags.size >= CAPS.fetch(@section.labels.range)

          flag = place(marker, item)
          flags << flag if flag
          tried << marker if flag || !swapped
        end
        flags
      end

      # Pins, then the swaps in their order, then everything else by rank.
      def order
        ranked = @section.order
        swapped = Array(@section.pick.swapped_ids).filter_map { |id| ranked.find { |item| item.id == id && !item.pinned? } }
        ranked.select(&:pinned?).map { |item| [ item, false ] } + swapped.map { |item| [ item, true ] } +
          (ranked.reject(&:pinned?) - swapped).map { |item| [ item, false ] }
      end

      def obstacles
        circles = @geometry.markers.map do |marker|
          reach = RADIUS + HALO
          Box.new(x: marker.x - reach, y: marker.y - reach, w: 2 * reach, h: 2 * reach, kind: :marker, marker: marker)
        end
        ex, ey = @geometry.line.last
        dot = END_DOT + HALO
        box = @geometry.end_box
        circles + [ Box.new(x: ex - dot, y: ey - dot, w: 2 * dot, h: 2 * dot, kind: :end, marker: nil),
                    Box.new(x: box.x, y: box.y, w: box.w, h: box.h, kind: :end_label, marker: nil) ]
      end

      def place(marker, item)
        reach = RADIUS + HALO
        tries(marker, Texts.new(item, @names).shapes).each do |shape, rise, side|
          y = marker.y - reach - rise - shape.h
          x = side == :left ? marker.x - GAP - shape.w : marker.x + GAP
          box = Box.new(x: x, y: y, w: shape.w, h: shape.h, kind: :flag, marker: nil)
          next unless inside?(box) && clear_of_line?(box)

          pole = Box.new(x: marker.x - 2.5, y: y, w: 5, h: marker.y - reach - y, kind: :pole, marker: nil)
          next if @obstacles.any? { |other| other.marker != marker && clash?(box, pole, other) }

          @obstacles.push(box, pole)
          return Flag.new(marker: marker, item: item, shape: shape, side: side, x: x, y: y, pole_x: marker.x,
                          pole_top: y + 1, pole_bottom: marker.y - reach)
        end
        nil
      end

      # Every try for one flag, cheapest first: the pole's rise plus the text's
      # height, with a cost on a second line when one would do. Left of the
      # circle goes first on a rising line.
      def tries(marker, shapes)
        one_line = shapes.any? { |shape| shape.lines.size == 1 }
        sides = sides_for(marker)
        all = shapes.each_with_index.flat_map do |shape, si|
          RISES.flat_map { |rise| sides.each_with_index.map { |side, k| [ shape, rise, side, si, k ] } }
        end
        all.sort_by { |shape, rise, _side, si, k| [ cost(shape, rise, one_line), si, k ] }.map { |shape, rise, side| [ shape, rise, side ] }
      end

      def sides_for(marker)
        left_first = marker.rising || marker.x - Geometry::LEFT > Geometry::RIGHT - marker.x
        left_first ? %i[left right] : %i[right left]
      end

      def cost(shape, rise, one_line)
        rise + shape.h + (one_line && shape.lines.size == 2 ? 1.5 * LEADING : 0)
      end

      def inside?(box)
        box.x >= Geometry::LEFT + 2 && box.x + box.w <= Geometry::RIGHT && box.y >= LOW && box.y + box.h <= HIGH
      end

      def clear_of_line?(box)
        floor = box.y + box.h + 3
        from = box.x - 3
        to = box.x + box.w + 3
        clear = (0..((to - from) / 1.5).floor).none? do |k|
          y = @geometry.line_y(from + (k * 1.5))
          y && y < floor
        end
        clear && @geometry.line.none? { |x, y| x.between?(from, to) && y < floor }
      end

      def clash?(box, pole, other)
        end_label = other.kind == :end_label
        return true if hits?(box, other, end_label ? END_PAD : 6, end_label ? 8 : 3)

        %i[flag end_label].include?(other.kind) && hits?(pole, other, 2, 2)
      end

      def hits?(one, other, pad_x, pad_y)
        !(one.x + one.w + pad_x <= other.x || other.x + other.w + pad_x <= one.x ||
          one.y + one.h + pad_y <= other.y || other.y + other.h + pad_y <= one.y)
      end
    end
  end
end
