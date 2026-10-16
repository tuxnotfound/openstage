module CardLayout
  class Footnotes
    # The right column's notes, set as large as they all fit: 32, 28, 24 or
    # 20px. Each title is balanced over at most three lines, then cut at a
    # word; a title ending in ":" runs on into its own body in muted ink,
    # word by word, within the same three lines. A pinned note ends in a star.
    # If six do not fit at 20px, the lowest-ranked note that is neither pinned
    # nor swapped in goes, then the earliest swap.
    class Notes
      TOP = 196
      BOTTOM = 548
      WIDTH = 424
      SIZES = [ 32, 28, 24, 20 ].freeze
      MAX_LINES = 3
      TITLE = :inter_medium
      RUN = :inter_regular

      # run starts with a space when it follows text on its line.
      Line = Data.define(:text, :run, :star)
      Note = Data.define(:item, :lines)
      Fit = Data.define(:size, :notes) do
        def line_height
          size * 1.25
        end

        def gap
          size / 2.0
        end
      end

      # items: the picked entries in date order; ranked: the same by rank.
      def self.fit(items, ranked:, swapped_ids:, project_names:)
        new(project_names).fit(items, ranked, Array(swapped_ids).map(&:to_i))
      end

      def initialize(project_names)
        @project_names = project_names
        @lines = {}
      end

      def fit(items, ranked, swapped_ids)
        items = items.dup
        while items.any?
          SIZES.each do |size|
            notes = items.map { |item| Note.new(item: item, lines: lines_of(item, size)) }
            return Fit.new(size: size, notes: notes) if height(notes, size) <= BOTTOM - TOP
          end
          items.delete(drop(items, ranked, swapped_ids))
        end
        Fit.new(size: SIZES.first, notes: [])
      end

      def self.star_width(size)
        (size * 0.2).round + (size * 0.62).round
      end

      private

      def height(notes, size)
        (notes.sum { |note| note.lines.size } * size * 1.25) + ((notes.size - 1) * size / 2.0)
      end

      # Past the unswapped notes, the earliest swap goes, so the latest one stays.
      def drop(items, ranked, swapped_ids)
        low = ranked.reverse.select { |item| items.include?(item) }
        swaps = items.select { |item| swapped_ids.include?(item.id) }.sort_by { |item| swapped_ids.index(item.id) }
        low.find { |item| !item.pinned? && swapped_ids.exclude?(item.id) } || swaps.first || low.first || items.last
      end

      def lines_of(item, size)
        title = keep_dashes(CardText.clean(item.title).presence || item.title)
        star = item.pinned? ? self.class.star_width(size) : 0
        texts, cut = wrap(title, size, star)
        lines = texts.map { |text| Line.new(text: text, run: "", star: false) }
        lines[-1] = lines[-1].with(star: item.pinned?)
        return lines if cut

        flow(run_in_words(item), Type.width(texts.last, TITLE, size) + star, lines, size)
      end

      # A lone dash never starts a line: a no-break space ties it to the word before.
      def keep_dashes(title)
        title.gsub(/ ([—–-])(?= |\z)/, "\u00A0\\1")
      end

      def run_in_words(item)
        CardText.clean(Progress::RunIn.of(item.title, item.body, @project_names)).split
      end

      # Balanced lines, or the first two greedy lines and a third cut at a
      # word with "…" when three are not enough. star: room the last line keeps.
      def wrap(title, size, star)
        balanced = (@lines[title] ||= Lines.new(title, TITLE, 0)).balance(size, WIDTH, MAX_LINES, tail: star)
        return [ balanced, false ] if balanced

        rows = greedy(title.split, size, WIDTH)
        kept = rows.first(MAX_LINES - 1)
        rest = rows.drop(MAX_LINES - 1).flatten
        [ kept.map { |row| row.join(" ") } + [ cut_line(rest, size, WIDTH - star) ], true ]
      end

      def greedy(words, size, room)
        words.each_with_object([ [] ]) do |word, rows|
          rows << [] if rows.last.any? && Type.width((rows.last + [ word ]).join(" "), TITLE, size) > room
          rows.last << word
        end
      end

      def cut_line(words, size, room)
        line = words.each_with_object([]) do |word, kept|
          break kept if Type.width("#{(kept + [ word ]).join(' ')}…", TITLE, size) > room

          kept << word
        end
        text = line.any? ? line.join(" ") : Type.cut(words.first.to_s, TITLE, size, 0, room).delete_suffix("…")
        "#{text.sub(/[\s,;:·–—.-]+\z/, '')}…"
      end

      # The run-in after the title's last line, onto the next ones while there
      # are any left of three; dropped when fewer than 6 characters fit.
      def flow(words, used, lines, size)
        rows = [ { at: lines.size - 1, words: [], used: used } ]
        cut = false
        words.each do |word|
          row = rows.last
          if row[:used] + run_width(lead(row, lines) + word, size) > WIDTH
            break cut = true if row[:at] + 1 >= MAX_LINES

            rows << (row = { at: row[:at] + 1, words: [], used: 0 })
          end
          row[:used] += run_width(lead(row, lines) + word, size)
          row[:words] << word
        end
        place(rows, cut, lines, size)
      end

      def place(rows, cut, lines, size)
        trim(rows.last, size) if cut
        kept = rows.select { |row| row[:words].any? }
        return lines if kept.map { |row| row[:words].join(" ") }.join(" ").grapheme_clusters.size < 6

        kept.each_with_object(lines.dup) do |row, out|
          text = row[:words].join(" ")
          text = "#{text.sub(/[\s,;:·–—-]+\z/, '')}…" if cut && row.equal?(rows.last)
          text = " #{text}" if row[:at] == lines.size - 1
          out[row[:at]] = row[:at] < out.size ? out[row[:at]].with(run: text) : Line.new(text: "", run: text, star: false)
        end
      end

      def trim(row, size)
        while row[:words].any? && row[:used] + run_width("…", size) > WIDTH
          row[:used] -= run_width(" #{row[:words].pop}", size)
        end
      end

      def lead(row, lines)
        row[:words].any? || row[:at] == lines.size - 1 ? " " : ""
      end

      def run_width(text, size)
        Type.width(text, RUN, size)
      end
    end
  end
end
