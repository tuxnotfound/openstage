module CardLayout
  class PixelStage
    # Drawing on the 4px grid: cells, rectangles, notched boxes, discs and
    # bitmaps, as path data. Numbers are written as JavaScript writes them.
    module Grid
      def rect(x, y, w, h)
        w.positive? && h.positive? ? "M#{num(x)} #{num(y)}h#{num(w)}v#{num(h)}h#{num(-w)}z" : ""
      end

      # A rectangle with its corners notched by one cell.
      def notch(x, y, w, h, n = P)
        "M#{num(x + n)} #{num(y)}H#{num(x + w - n)}V#{num(y + n)}H#{num(x + w)}V#{num(y + h - n)}H#{num(x + w - n)}V#{num(y + h)}" \
          "H#{num(x + n)}V#{num(y + h - n)}H#{num(x)}V#{num(y + n)}H#{num(x + n)}Z"
      end

      # A filled disc, one cell row at a time.
      def disc(cx, cy, r)
        (-r...r).step(P).map do |dy|
          half = snap(Math.sqrt([ 0, (r * r) - ((dy + 2)**2) ].max))
          rect(cx - half, cy + dy, 2 * half, P)
        end.join
      end

      # JavaScript's Math.round to the grid, so halves go up.
      def snap(value)
        ((value / P.to_f) + 0.5).floor * P
      end

      def num(value)
        value == value.to_i ? value.to_i.to_s : value.to_s
      end

      # Draws a bitmap, one colour per letter.
      def bitmap(stage, rows, x, y, palette, cell = P, opacity = 1)
        paths = Hash.new { |hash, key| hash[key] = +"" }
        rows.each_with_index do |row, j|
          row.each_char.with_index { |char, i| paths[palette[char]] << rect(x + (i * cell), y + (j * cell), cell, cell) if palette[char] }
        end
        paths.each { |fill, d| put(stage, fill, d, opacity) }
      end
    end
  end
end
