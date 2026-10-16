module CardLayout
  class StarChart
    # One row's words and its projects: the counts closing the last line, or
    # a sub-line under the words that names each project with its commits.
    class RowMarks
      def initialize(chart)
        @canvas = chart.canvas
        @palette = chart.palette
      end

      # tone: :title for the builder's words, :auto for words the card wrote.
      def draw(fit, level, baseline, tone)
        fit.lines.each_with_index do |line, k|
          y = baseline + (k * level[:lh])
          @canvas.put(line.text, :dm_sans_medium, level[:size], LEFT + HEAD_X, y, @palette[tone]) if line.text.present?
          inline(fit.meta, y) if line.meta
        end
        sub(fit.sub, baseline - StarChart.base_in(level[:lh], level[:size]) + (fit.lines.size * level[:lh]), level) if fit.sub.any?
      end

      private

      def mono(text)
        CardText.width(text, size: RowFit::META_S, face: :dm_mono_regular)
      end

      # Right-aligned on the line. A dot sits half a pixel above its count's
      # baseline.
      def inline(marks, baseline)
        x = LEFT + WIDTH - (marks.sum { |mark| (mark.dot ? 11 : 0) + mono(mark.count) } + (10 * (marks.size - 1)))
        marks.each do |mark|
          if mark.dot
            @canvas.dot(x + 3.5, baseline - 4, 3.5, mark.dot)
            x += 11
          end
          @canvas.put(mark.count, :dm_mono_regular, RowFit::META_S, x, baseline, @palette[:num])
          x += mono(mark.count) + 10
        end
      end

      def sub(marks, top, level)
        baseline = top + StarChart.base_in(level[:sub_h], marks.any?(&:name) ? RowFit::SUB_S : RowFit::META_S)
        marks.inject(LEFT + HEAD_X) do |x, mark|
          if mark.dot
            @canvas.dot(x + 3.5, baseline - 4, 3.5, mark.dot)
            x += 12
          end
          x = @canvas.put(mark.name, :dm_sans_regular, RowFit::SUB_S, x, baseline, @palette[:sub_name]) + 5 if mark.name
          @canvas.put(mark.count, :dm_mono_regular, RowFit::META_S, x, baseline, @palette[:num]) + RowFit::SUB_GAP
        end
      end
    end
  end
end
