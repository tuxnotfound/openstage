module CardLayout
  class StarChart
    # Every day of the week as a row, in order, between the persona and the
    # totals. An active row: the day and its kind in the gutter, a glyph that
    # matches the sky (a nova, a comet, or a dot for a day of commits), the
    # builder's words, and the projects. A quiet day is a slim row that keeps
    # its place; runs of quiet days share one row only when seven cannot fit.
    class Rows
      # From roomy to tight. The first plan that fits wins, so a thin week
      # reads large and a full one stays whole.
      LEVELS = [ [ 22, 28, 11, 9, 18 ], [ 20, 26, 10, 8, 17 ], [ 19, 25, 9, 7, 17 ], [ 18, 24, 8, 6, 17 ], [ 18, 23, 7, 6, 16 ],
                 [ 17, 22, 7, 6, 16 ], [ 16, 21, 6, 5, 16 ], [ 16, 20, 5, 4, 15 ], [ 15, 19, 5, 4, 15 ], [ 15, 18, 4, 3, 15 ],
                 [ 14, 17, 3, 3, 14 ], [ 13, 16, 2, 2, 14 ] ].map { |size, lh, pad, qpad, sub_h| { size:, lh:, pad:, qpad:, sub_h: } }.freeze
      QUIET_H = 18
      Item = Data.define(:day, :to, :fit)

      def initialize(chart)
        @chart = chart
        @canvas = chart.canvas
        @palette = chart.palette
        @fits = {}
      end

      # Draws the rows from top within the room, and says where they end.
      def draw(top, bottom)
        level, mode, items = plan(bottom - top)
        heights = heights(items, level, mode)
        extra = ((bottom - top - heights.sum) / (2.0 * [ items.size, 1 ].max)).floor.clamp(0, 12)
        items.each_with_index.inject(top) do |y, (item, k)|
          height = heights[k] + (2 * extra)
          @canvas.draw(k.zero? ? :rules : :hairs, Shapes.rule(LEFT, LEFT + WIDTH, y))
          item.fit ? active(item, level, mode, y, extra) : quiet(item, y, height)
          y + height
        end
      end

      private

      # Seven rows with named sub-lines, then seven with dots inline, then
      # the same with quiet days merged; the last resort goes down to 13px.
      def plan(room)
        plans.each_with_index do |(level, mode, merge), k|
          items = items(merge)
          return [ level, mode, items ] if heights(items, level, mode).sum <= room || k == plans.size - 1
        end
      end

      def plans
        roomy, tight = LEVELS.partition { |level| level[:size] >= 15 }
        [ nil, 2 ].flat_map { |merge| %i[sub inline].flat_map { |mode| roomy.map { |level| [ level, mode, merge ] } } } +
          tight.map { |level| [ level, :inline, 2 ] }
      end

      def heights(items, level, mode)
        items.map { |item| item.fit ? item.fit.at(level, mode).height : QUIET_H + (2 * level[:qpad]) }
      end

      def items(merge)
        runs = @chart.days.slice_when { |a, b| a.active? || b.active? }.to_a
        runs.flat_map do |run|
          next [ Item.new(day: run.first, to: nil, fit: fit(run.first)) ] if run.first.active?
          next [] if @chart.card.week_card.layout == "active"

          merge && run.size >= merge ? [ Item.new(day: run.first, to: run.last, fit: nil) ] : run.map { |day| Item.new(day: day, to: nil, fit: nil) }
        end
      end

      def fit(day)
        @fits[day.index] ||= RowFit.new(@chart, day, auto?(day) ? auto_title(day) : day.title)
      end

      def auto?(day)
        day.title.blank?
      end

      # The card writes a day's words only when the builder did not.
      def auto_title(day)
        count = day.commits
        return { "shipped" => "Shipped", "published" => "Published" }.fetch(day.kind, "Built") if count.zero?
        return "#{count.to_fs(:delimited)} #{'commit'.pluralize(count)}" unless @chart.shows?("projects")

        day.projects.size > 1 ? "#{count} commits in #{day.projects.size} projects" : "#{count.to_fs(:delimited)} #{'commit'.pluralize(count)} in #{day.projects.first.first}"
      end

      def quiet(item, top, height)
        label = item.to ? "#{item.day.label} – #{item.to.label}" : item.day.label
        baseline = top + 1 + ((height - QUIET_H) / 2.0) - 0.5 + StarChart.base_in(QUIET_H, 11.5)
        @canvas.put(label, :dm_mono_regular, 11.5, LEFT, baseline, @palette[:faint], spacing: 0.06)
        day_w = CardText.width(label, size: 11.5, face: :dm_mono_regular, spacing: 0.06 * 11.5)
        @canvas.put("quiet", :newsreader_note, 15, LEFT + [ HEAD_X, day_w + 12 ].max, baseline, @palette[:faint])
      end

      def active(item, level, mode, top, extra)
        fit = item.fit.at(level, mode)
        content = top + 1 + level[:pad] + extra - 0.5
        baseline = content + StarChart.base_in(level[:lh], level[:size])
        gutter(item.day, fit, level, mode, baseline)
        glyph(item.day.kind, content + ((StarChart.base_in(level[:lh], level[:size]) - (0.25 * level[:size]) - 6.5) * 10).round / 10.0)
        RowMarks.new(@chart).draw(fit, level, baseline, auto?(item.day) ? :auto : :title)
      end

      # The gutter hangs from the day's baseline; the tag then lines up with
      # the sub-line when the words take one line, and with their second line
      # otherwise.
      def gutter(day, fit, level, mode, baseline)
        shipped = day.kind == "shipped"
        @canvas.put(day.label, :dm_mono_regular, 11.5, LEFT, baseline, @palette[shipped ? :gold : :muted], spacing: 0.06)
        tag = { "shipped" => [ "SHIPPED", :gold ], "published" => [ "PUBLISHED", :pub ] }.fetch(day.kind, [ "BUILT", :faint ])
        top = baseline - StarChart.base_in(level[:lh], 11.5) + level[:lh] + nudge(fit, level, mode)
        @canvas.put(tag.first, :dm_mono_regular, 9.5, LEFT, top + StarChart.base_in(level[:sub_h], 9.5), @palette[tag.last], spacing: 0.1)
      end

      def nudge(fit, level, mode)
        base = ->(box, size) { StarChart.base_in(box, size) }
        nudge = if fit.lines.size == 1 && mode == :sub && fit.sub.any?
          base.call(level[:sub_h], 12) - (base.call(level[:lh], level[:size]) - base.call(level[:lh], 11.5)) - base.call(level[:sub_h], 9.5)
        elsif fit.lines.size > 1 then base.call(level[:lh], 11.5) - base.call(level[:sub_h], 9.5)
        else 0
        end
        (nudge * 10).round / 10.0
      end

      def glyph(kind, top)
        x = LEFT + GUTTER
        case kind
        when "shipped" then @canvas.icon(x, top, 13, "0 0 24 24", STAR, @palette[:gold])
        when "published"
          @canvas.icon(x, top, 13, "0 0 24 24", COMET_TAIL, @palette[:pub], opacity: 0.5)
          @canvas.icon(x, top, 13, "0 0 24 24", COMET_HEAD, @palette[:pub])
        else @canvas.icon(x, top, 13, "0 0 24 24", DOT, @palette[:muted])
        end
      end
    end
  end
end
