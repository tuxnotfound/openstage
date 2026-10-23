module CardLayout
  class Progress
    # Every line of text on the progress card, measured and placed: the
    # header, the chart's labels and disc numbers, and the notes column.
    class Words
      SANS = :funnel_sans_regular
      SANS_BOLD = :funnel_sans_semibold
      DISPLAY = :funnel_display_bold
      FIGURES = :funnel_display_figures

      # A title in at most two lines, the second cut on a word.
      def self.wrap(title, room)
        words = title.split(" ")
        first = []
        first << words.shift while words.any? && Type.width((first + [ words.first ]).join(" "), SANS_BOLD, TITLE) <= room
        return [ Type.cut(title, SANS_BOLD, TITLE, 0, room) ] if first.empty?
        return [ first.join(" ") ] if words.empty?

        [ first.join(" "), Type.cut_words(words.join(" "), SANS_BOLD, TITLE, 0, room) ]
      end

      def initialize(card)
        @card = card
        @canvas = card.canvas
        @palette = card.palette
      end

      def draw
        header
        chart_labels
        notes
      end

      private

      def header
        section = @card.section
        x = @card.avatar_url ? 128 : LEFT
        @canvas.put(Type.cut(@card.user.display_name.to_s, DISPLAY, 30, 0, 560 - x), DISPLAY, 30, x, 90, @palette[:ink])
        scope = [ (section.selection_name if section.filtered?), section.labels.words, "openstage.dev/#{@card.user.username}" ].compact
        @canvas.put(Type.cut(scope.join(" · ").upcase_first, SANS, 16, 0, 820 - x), SANS, 16, x, 117, @palette[:muted])
        @canvas.put_end(Type.number(section.tally.totals.commits), FIGURES, 60, RIGHT, 100, @palette[:ink])
        @canvas.put_end(section.tally.totals.commits == 1 ? "commit" : "commits", SANS, 15, RIGHT, 124, @palette[:muted])
      end

      def chart_labels
        @card.chart.ticks.each { |tick| @canvas.put_end(tick.value.to_s, SANS, 13, PLOT[:left] - 12, @card.plot_y(tick.top) + 4.5, @palette[:muted]) }
        axis
        @card.discs.zip(@card.chart.discs).each do |disc, placed|
          centered(placed.number.to_s, DISPLAY, 14, disc.cx, disc.cy + 4.8, ProgressChart::Palette.ink_on(disc.fill))
        end
        empty = "No commits #{@card.section.labels.word}."
        centered(empty, SANS, 16, (PLOT[:left] + PLOT[:right]) / 2.0, (PLOT[:top] + PLOT[:bottom]) / 2.0, @palette[:muted]) if @card.chart.lines.empty?
      end

      def axis
        labels = @card.chart.axis
        baseline = PLOT[:bottom] + 28
        @canvas.put(labels.first, SANS, 13, PLOT[:left], baseline, @palette[:muted])
        centered(labels[1], SANS, 13, @card.plot_x(@card.section.tally.period.buckets.size / 2), baseline, @palette[:muted]) if labels.size == 3
        @canvas.put_end(labels.last, SANS_BOLD, 13, PLOT[:right], baseline, @palette[:ink])
      end

      def notes
        @canvas.put("Shipped and published", SANS_BOLD, 13, NOTES[:left], NOTES[:top] + 4, @palette[:muted])
        @card.notes.each_with_index do |note, i|
          disc = @card.note_disc(note)
          centered((i + 1).to_s, DISPLAY, 12, disc.cx, disc.cy + 4.2, ProgressChart::Palette.ink_on(disc.fill))
          note.lines.each_with_index { |line, k| @canvas.put(line, SANS_BOLD, TITLE, NOTE_TEXT, note.top + 15 + (k * LEAD), @palette[:ink]) }
          @canvas.put(note.meta, SANS, 13, NOTE_TEXT, note.top + 15 + (note.lines.size * LEAD), @palette[:muted])
        end
        return if @card.left_out.empty?

        @canvas.put("#{@card.left_out.size} more #{@card.section.labels.word} on the page", SANS, 13, NOTES[:left], NOTES[:more], @palette[:muted])
      end

      def centered(text, face, size, x, baseline, color)
        @canvas.put(text, face, size, x - (Type.width(text, face, size) / 2.0), baseline, color)
      end
    end
  end
end
