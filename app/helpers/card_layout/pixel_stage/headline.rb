module CardLayout
  class PixelStage
    # A builder's headline in its callout: 14px down to 11px. Every size is
    # tried and the most even wrap wins, with a small cost per step down.
    # Words break at their own hyphens only when nothing else fits; a word
    # wider than the box breaks anywhere, with a hyphen.
    class Headline
      SIZES = [ 14, 13, 12, 11 ].freeze
      Piece = Data.define(:text, :glue)

      attr_reader :size, :lines

      def initialize(text, width, max_lines)
        @text = text
        @width = width
        @size, @lines = fit(max_lines)
      end

      private

      def measure(text, size)
        CardText.width(text, size: size, face: :pixelify_medium)
      end

      def fit(max_lines)
        [ false, true ].each do |hyphens|
          picks = SIZES.filter_map do |size|
            cost, lines = balanced(size, max_lines, hyphens)
            [ cost + ((14 - size) * 0.3) + (lines.size * 0.03), size, lines ] if lines
          end
          best = picks.min_by(&:first)
          return best.drop(1) if best
        end
        [ 11, cut(hard(11), max_lines) ]
      end

      def pieces(hyphens)
        @text.split(/\s+/).reject(&:empty?).each_with_index.flat_map do |word, w|
          (hyphens ? word.split(/(?<=-)/) : [ word ]).each_with_index.map { |part, p| Piece.new(text: part, glue: p.zero? && w.positive? ? " " : "") }
        end
      end

      def join(pieces)
        pieces.each_with_index.map { |piece, k| (k.positive? ? piece.glue : "") + piece.text }.join
      end

      # The least squared slack over every line but the last, in at most
      # max_lines lines. A lone short word on the last line costs a little,
      # and so does a break inside a word.
      def balanced(size, max_lines, hyphens)
        list = pieces(hyphens)
        return if list.empty? || list.any? { |piece| measure(piece.text, size) > @width }

        n = list.size
        best = Array.new(n + 1) { Array.new(max_lines + 1) }
        (0..max_lines).each { |k| best[n][k] = [ 0, n ] }
        (n - 1).downto(0) do |i|
          (1..max_lines).each { |k| best[i][k] = step(list, best, i, k, size) }
        end
        return unless best[0][max_lines]

        [ best[0][max_lines].first, unwind(list, best, max_lines) ]
      end

      # The cheapest first line from piece i with k lines left: [cost, end].
      def step(list, best, i, k, size)
        pick = nil
        ((i + 1)..list.size).each do |j|
          width = measure(join(list[i...j]), size)
          break if width > @width
          next unless best[j][k - 1]

          cost = line_cost(list, i, j, width) + best[j][k - 1].first
          pick = [ cost, j ] if pick.nil? || cost < pick.first
        end
        pick
      end

      def line_cost(list, i, j, width)
        last = j == list.size
        cost = last ? 0 : ((@width - width) / @width.to_f)**2
        cost += 0.12 if last && i.positive? && j - i == 1 && width < @width * 0.34
        cost += 0.04 if !last && list[j].glue.empty?
        cost
      end

      def unwind(list, best, max_lines)
        lines = []
        i, k = 0, max_lines
        while i < list.size
          j = best[i][k].last
          lines << join(list[i...j])
          i, k = j, k - 1
        end
        lines
      end

      # Greedy, with an added hyphen three letters from either end.
      def hard(size)
        lines = [ +"" ]
        @text.split(/\s+/).reject(&:empty?).each do |word|
          glue = " "
          word.split(/(?<=-)/).each do |piece|
            while measure(piece, size) > @width
              at = piece.delete_suffix("-").length - 3
              at -= 1 while at > 3 && measure("#{piece[0, at]}-", size) > @width
              place(lines, "#{piece[0, at]}-", glue, size)
              lines << +""
              glue = ""
              piece = piece[at..]
            end
            place(lines, piece, glue, size)
            glue = ""
          end
        end
        lines.reject(&:empty?)
      end

      # Onto the current line when it fits, else onto a new one.
      def place(lines, piece, glue, size)
        joined = lines.last.empty? ? piece : "#{lines.last}#{glue}#{piece}"
        if lines.last.empty? || measure(joined, size) <= @width then lines[-1] = +joined
        else lines << +piece
        end
      end

      def cut(lines, max_lines)
        return lines if lines.size <= max_lines

        kept = lines.first(max_lines)
        last = kept.last
        last = last[0...-1] while last.length > 1 && measure("#{last}…", 11) > @width
        kept[-1] = "#{last.sub(/[\s-]+\z/, '')}…"
        kept
      end
    end
  end
end
