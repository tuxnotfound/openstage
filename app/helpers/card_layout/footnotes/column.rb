module CardLayout
  class Footnotes
    # The right column: what the period holds, the numbered notes, and how
    # many more are on the page; or one line when there is nothing to note.
    class Column
      def initialize(layout)
        @layout = layout
        @canvas = layout.canvas
        @palette = layout.palette
        @section = layout.section
      end

      def draw
        head
        @layout.fit.notes.any? ? notes : empty
        footer
      end

      private

      # "● 10 SHIPPED   ○ 10 PUBLISHED"; a kind with none is left out.
      def head
        totals = @section.tally.totals
        x = NOTES_X
        [ [ totals.shipped, "SHIPPED", true ], [ totals.published, "PUBLISHED", false ] ].each do |count, word, shipped|
          next if count.zero?

          glyph(x, shipped)
          x = @canvas.put("#{count} #{word}", :dm_mono_medium, 12, x + 18, 166 + 7 + (0.34 * 12), @palette[:muted], spacing: 0.14) + 22
        end
      end

      def glyph(x, shipped)
        if shipped
          @canvas.draw(:disc_ship, Shapes.rounded(x, 168, 10, 10, 5))
        else
          @canvas.draw(:disc_post, Shapes.rounded(x, 168, 10, 10, 5))
          @canvas.draw(:disc_ring, Shapes.rounded(x + 0.9, 168.9, 8.2, 8.2, 4.1))
        end
      end

      def notes
        fit = @layout.fit
        top = Notes::TOP
        fit.notes.each_with_index do |note, k|
          @layout.disc(NOTES_X, top + (fit.line_height / 2) - 10, 20, (k + 1).to_s, note.item.shipped?)
          note.lines.each_with_index { |line, i| note_line(line, fit, top + (i * fit.line_height)) }
          top += (note.lines.size * fit.line_height) + fit.gap
        end
      end

      def note_line(line, fit, top)
        size = fit.size
        baseline = top + (fit.line_height / 2) + (INTER_BASE * size)
        x = line.text.empty? ? TEXT_X : @canvas.put(line.text, Notes::TITLE, size, TEXT_X, baseline, @palette[:ink])
        x = star(x, baseline, size) if line.star
        return if line.run.blank?

        # SVG drops a leading space, so the space after the title is an advance.
        x += Type.width(" ", Notes::RUN, size) if line.run.start_with?(" ")
        @canvas.put(line.run.lstrip, Notes::RUN, size, x, baseline, @palette[:muted])
      end

      # The star after a pinned note's title, as tall as 0.62em.
      def star(x, baseline, size)
        side = (size * 0.62).round
        @canvas.icon(x + (size * 0.2).round, baseline - (0.02 * size) - side, side, "0 0 24 24", STAR, @palette[:ink])
        x + Notes.star_width(size)
      end

      def empty
        text = if @section.filtered?
          @section.labels.empty_tagged(@section.selection_name(alternatives: true), yet: true)
        else
          @section.labels.empty
        end
        lines = Lines.new(text, :inter_medium, 0).balance(24, Notes::WIDTH, 3) || [ text ]
        lines.each_with_index do |line, i|
          @canvas.put(line, :inter_medium, 24, NOTES_X, Notes::TOP + (i * 30) + 15 + (INTER_BASE * 24), @palette[:muted])
        end
      end

      # "+14 more at openstage.dev/tuxnotfound"
      def footer
        more = @layout.left_out.size
        return if more.zero?

        @canvas.put("+#{more} more at openstage.dev/#{@layout.user.username}", :inter_regular, 14, NOTES_X,
                    560 + 9 + (INTER_BASE * 14), @palette[:muted])
      end
    end
  end
end
