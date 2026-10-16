module CardLayout
  class Journey
    # How one entry's title can sit on a flag, in the order the flags try
    # them: one line if it fits the 290px measure; two balanced lines when the
    # title is wider than 60% of the measure and the pair is clearly narrower;
    # two lines cut at a word with "…" when it needs more. A title ending in
    # ":" also gets its body as a muted run-in, only in the room its last line
    # has left, so it never adds a line; the plain shape follows each run-in one.
    class Texts
      def initialize(item, project_names)
        @item = item
        @face = Flags::FACES.fetch(Flags.weight(item))
        @title = CardText.clean(item.title).presence || item.title.to_s
        @title = @title.gsub(/(\w)'(\w)/, "\\1’\\2").gsub(/ ([—–-])(?= |\z)/, " \\1")
        @body = CardText.clean(Progress::RunIn.of(item.title, item.body, project_names))
      end

      def shapes
        line_shapes.flat_map do |lines|
          widths = lines.map { |line| width(line) }
          gap = width(" ")
          run = fit_run(Flags::MEASURE - widths.last - gap)
          height = lines.size * Flags::LEADING
          plain = Flags::Shape.new(lines: lines, run: "", w: widths.max, h: height)
          next [ plain ] if run.empty?

          w = (widths[0...-1] + [ widths.last + gap + run_width(run) ]).max
          [ Flags::Shape.new(lines: lines, run: run, w: w, h: height), plain ]
        end
      end

      private

      def line_shapes
        one = width(@title)
        two = two_lines([ Flags::MEASURE, one - 0.5 ].min)
        shapes = []
        shapes << [ @title ] if one <= Flags::MEASURE
        shapes << two if two.size == 2 && (shapes.empty? || (one > 0.6 * Flags::MEASURE && two.map { |line| width(line) }.max < 0.8 * one))
        shapes << two if shapes.empty?
        shapes
      end

      # Two balanced lines, or the first greedy line and a second cut at a word.
      def two_lines(room)
        balanced = Lines.new(@title, @face, 0).balance(Flags::SIZE, room, 2)
        return balanced if balanced

        words = @title.split
        first = []
        first << words.shift while words.any? && width((first + [ words.first ]).join(" ")) <= Flags::MEASURE
        [ first.join(" "), cut(words) ].reject(&:empty?)
      end

      def cut(words)
        kept = []
        kept << words.shift while words.any? && width("#{(kept + [ words.first ]).join(' ')}…") <= Flags::MEASURE
        kept.empty? ? "" : "#{kept.join(' ').sub(/[\s,;:·–—.-]+\z/, '')}…"
      end

      # The run-in in the room left, cut at a word with "…"; dropped when
      # fewer than 6 characters fit.
      def fit_run(room)
        return "" if @body.empty? || room <= 0
        return @body if run_width(@body) <= room

        kept = []
        @body.split.each do |word|
          break if run_width("#{(kept + [ word ]).join(' ')}…") > room

          kept << word
        end
        text = kept.join(" ").sub(/[\s,;:·–—.-]+\z/, "")
        text.grapheme_clusters.size >= 6 ? "#{text}…" : ""
      end

      def width(text)
        Type.width(text, @face, Flags::SIZE)
      end

      def run_width(text)
        Type.width(text, :inter_regular, Flags::SIZE)
      end
    end
  end
end
