module CardLayout
  # Balanced line breaking for one text in one face: the fewest lines that
  # fit, then the split with the least sum of squared line widths. Breaks
  # inside a word, after a hyphen, only when spaces are not enough. Widths
  # scale with the size, so each span is measured once at 1px and trying many
  # sizes stays cheap. Two templates price a break differently:
  #   :weak_end (Changelog) avoids ending a line on a short word, and may also
  #   break after an underscore or slash;
  #   :phrases (Star Chart) prefers breaking after punctuation, so phrases
  #   stay whole.
  class Lines
    # A line that ends on one of these ("coding for a / week") costs as much
    # as a quarter of the measure left empty, so a break takes it only when
    # nothing else fits.
    WEAK_END = %w[a an the to of in on for and or at by with my i is].to_set.freeze
    SPLITS = { weak_end: %r{(?<=[-_/])(?=.)}, phrases: /(?<=-)(?=.)/ }.freeze
    Token = Data.define(:text, :space)

    def initialize(text, face, spacing, rule: :weak_end)
      @text, @face, @spacing, @rule = text, face, spacing, rule
      @tokens = {}
      @units = {}
    end

    # The lines at a size, or nil when the text needs more than max_lines.
    # tail: room kept at the end of the last line.
    def balance(size, room, max_lines, tail: 0)
      @tail = tail
      [ false, true ].each do |hyphens|
        (1..[ max_lines, tokens(hyphens).size ].min).each do |count|
          lines = best(hyphens, size, room, count)
          return lines if lines
        end
      end
      nil
    end

    private

    def tokens(hyphens)
      @tokens[hyphens] ||= @text.split(" ").each_with_index.flat_map do |word, at|
        parts = hyphens ? word.split(SPLITS.fetch(@rule)) : [ word ]
        parts.each_with_index.map { |part, i| Token.new(text: part, space: i.zero? && at.positive?) }
      end
    end

    def join(list)
      list.each_with_index.map { |token, i| (i.positive? && token.space ? " " : "") + token.text }.join
    end

    # Each span's width at 1px, by its first and last-plus-one token.
    def units(hyphens)
      @units[hyphens] ||= begin
        list = tokens(hyphens)
        (0...list.size).to_h do |from|
          [ from, ((from + 1)..list.size).to_h { |to| [ to, Type.width(join(list[from...to]), @face, 1, @spacing) ] } ]
        end
      end
    end

    def best(hyphens, size, room, count)
      costs, starts = table(hyphens, size, room, count)
      backtrack(hyphens, starts, count) unless costs[count][tokens(hyphens).size].infinite?
    end

    def table(hyphens, size, room, count)
      ends = tokens(hyphens).size
      costs = Array.new(count + 1) { Array.new(ends + 1, Float::INFINITY) }
      starts = Array.new(count + 1) { Array.new(ends + 1, 0) }
      costs[0][0] = 0
      (1..count).each do |line|
        (line..ends).each do |stop|
          ((line - 1)...stop).each do |start|
            cost = cost(hyphens, size, room, start, stop)
            next unless cost

            total = costs[line - 1][start] + cost
            costs[line][stop], starts[line][stop] = total, start if total < costs[line][stop]
          end
        end
      end
      [ costs, starts ]
    end

    def cost(hyphens, size, room, start, stop)
      last = stop == tokens(hyphens).size
      width = (units(hyphens)[start][stop] * size) + (last ? @tail : 0)
      return if width > room

      (width**2) + (last ? 0 : penalty(tokens(hyphens)[stop - 1].text, room))
    end

    def penalty(word, room)
      return (word.match?(/[:,;–—-]\z/) ? 0 : 0.06 * room * room) if @rule == :phrases

      WEAK_END.include?(word.downcase.gsub(/[^a-z]/, "")) ? (0.25 * room)**2 : 0
    end

    def backtrack(hyphens, starts, count)
      stop = tokens(hyphens).size
      count.downto(1).map do |line|
        start = starts[line][stop]
        join(tokens(hyphens)[start...stop]).tap { stop = start }
      end.reverse
    end
  end
end
