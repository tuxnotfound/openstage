module CardLayout
  class StarChart
    # How one active day's row fits at one size: its lines, and its projects
    # either on a sub-line under the words (each named, with its commits) or
    # as dots and counts closing the last line. The builder's words are never
    # cut: a row wraps, up to three lines, and shrinks before anything gives.
    class RowFit
      META_S = 11.5
      SUB_S = 12
      SUB_GAP = 14
      # text: what the line says; meta: whether the inline counts close it.
      Line = Data.define(:text, :meta)
      # dot: a colour, or nil for "+N".
      Mark = Data.define(:name, :full, :count, :dot)
      Fit = Data.define(:lines, :meta, :sub, :height)

      def initialize(chart, day, text)
        @chart = chart
        @day = day
        @text = text
        @lines = Lines.new(text, :dm_sans_medium, 0, rule: :phrases)
      end

      def sub
        @sub ||= @chart.shows?("projects") && @day.projects.any? ? fit_sub : []
      end

      def at(level, mode)
        mode == :sub ? sub_fit(level) : inline_fit(level)
      end

      private

      # A day without commits has no sub-line; its row keeps room for the tag.
      def sub_fit(level)
        lines = break_lines(level[:size], 0) || hard_wrap(level[:size])
        body = sub.any? ? (lines.size * level[:lh]) + level[:sub_h] : [ lines.size * level[:lh], level[:lh] + level[:sub_h] ].max
        Fit.new(lines: lines.map { |text| Line.new(text: text, meta: false) }, meta: [], sub: sub, height: (2 * level[:pad]) + body)
      end

      def inline_fit(level)
        meta = inline_marks
        tail = meta.any? ? marks_width(meta) + 16 : 0
        lines = break_lines(level[:size], tail)
        own = lines.nil? && tail.positive?
        lines ||= break_lines(level[:size], 0) || hard_wrap(level[:size])
        out = lines.each_with_index.map { |text, k| Line.new(text: text, meta: !own && tail.positive? && k == lines.size - 1) }
        out << Line.new(text: "", meta: true) if own
        Fit.new(lines: out, meta: meta, sub: [], height: (2 * level[:pad]) + [ out.size * level[:lh], level[:lh] + level[:sub_h] ].max)
      end

      def break_lines(size, tail)
        @lines.balance(size, HEAD_W, 3, tail: tail)
      end

      # Last resort for a word longer than the line: break it anywhere.
      def hard_wrap(size)
        StarChart.hard_wrap(@text, HEAD_W) { |text| CardText.width(text, size: size, face: :dm_sans_medium) }
      end

      # Dense weeks: up to three projects, or two and "+N" past three.
      def inline_marks
        return [] unless @chart.shows?("projects")

        shown = @day.projects.first(@day.projects.size > 3 ? 2 : 3).map { |name, n| Mark.new(name: nil, full: name, count: n.to_s, dot: @chart.dot_color(name)) }
        rest = @day.projects.size - shown.size
        rest.positive? ? shown + [ Mark.new(name: nil, full: nil, count: "+#{rest}", dot: nil) ] : shown
      end

      def marks_width(marks)
        marks.sum { |mark| (mark.dot ? 11 : 0) + mono(mark.count) } + (10 * [ marks.size - 1, 0 ].max)
      end

      def mono(text)
        CardText.width(text, size: META_S, face: :dm_mono_regular)
      end

      def sans(text)
        CardText.width(text, size: SUB_S, face: :dm_sans_regular)
      end

      def sub_width(marks)
        marks.sum { |mark| (mark.dot ? 12 : 0) + (mark.name ? sans(mark.name) + 5 : 0) + mono(mark.count) } + (SUB_GAP * [ marks.size - 1, 0 ].max)
      end

      # Every project of the day with its commits. Long repo names are
      # shortened before a project is dropped.
      def fit_sub
        all = @day.projects.map { |name, n| Mark.new(name: name, full: name, count: n.to_s, dot: @chart.dot_color(name)) }
        all.size.downto(1) do |keep|
          marks = all.first(keep)
          marks += [ Mark.new(name: nil, full: nil, count: "+#{all.size - keep}", dot: nil) ] if keep < all.size
          marks = shorten(marks)
          return marks if sub_width(marks) <= HEAD_W
        end
        all.first(1)
      end

      def shorten(marks)
        40.times do
          break if sub_width(marks) <= HEAD_W

          widest = marks.select(&:name).max_by { |mark| sans(mark.name) }
          break if widest.nil? || sans(widest.name) <= 96

          room = [ 96, sans(widest.name) - (sub_width(marks) - HEAD_W) - 1 ].max
          marks = marks.map { |mark| mark.equal?(widest) ? mark.with(name: StarChart.cut(mark.full, room) { |text| sans(text) }) : mark }
        end
        marks
      end
    end
  end
end
