module CardLayout
  class Footnotes
    # The left column's chart: the period's bars stacked by project, numbered
    # discs on the buckets holding the notes, the axes, and as many projects
    # in the legend as fit.
    class Chart
      FRAME = ProgressChart::Bars::Frame.new(left: 96, right: 620, top: 318, bottom: 528)
      SHAPE = ProgressChart::Discs::Shape.new(size: 20, pill: 32, gap: 2, lift: 4)
      LEGEND_TOP = 562
      LEGEND_WIDTH = 560
      LEGEND_GAP = 22

      attr_reader :discs

      # items: the notes that made the card, in date order.
      def initialize(layout, items)
        @layout = layout
        @canvas = layout.canvas
        @palette = layout.palette
        @section = layout.section
        @bars = ProgressChart::Bars.new(tally.buckets, repos: tally.projects.all.map(&:repo), colors: colors, frame: FRAME)
        @discs = ProgressChart::Discs.new(items, period: tally.period, bars: @bars, shape: SHAPE).all
      end

      def draw
        @bars.fills.each { |path, color| @layout.fill(path, color) }
        axes
        @discs.each { |disc| @layout.disc(disc.x - (disc.width / 2.0), disc.cy - (SHAPE.size / 2.0), disc.width, disc.label, disc.shipped?) }
        legend unless @section.project
      end

      private

      def tally
        @section.tally
      end

      def colors
        colors = tally.projects.all.to_h { |project| [ project.repo, project_color(project.rank) ] }
        colors.default = project_color(nil)
        colors
      end

      def project_color(rank)
        ProgressChart::Palette.project_color(rank, @layout.theme.to_sym)
      end

      def axes
        scale = @bars.scale
        scale.ticks.drop(1).each do |value|
          @canvas.draw(:rules, "M#{FRAME.left},#{Shapes.num(scale.y(value).round(1) + 0.5)}H#{FRAME.right}")
          @canvas.put_end(value.to_s, :dm_mono_regular, 11, 88, scale.y(value) + (0.34 * 11), @palette[:faint])
        end
        @canvas.draw(:rules_strong, "M#{FRAME.left},#{FRAME.bottom + 0.5}H#{FRAME.right}")
        axis_labels
      end

      def axis_labels
        inks = { now: @palette[:ink], future: @palette[:rule_strong], past: @palette[:faint] }
        tally.period.buckets.each do |bucket|
          text = @section.labels.axis(bucket).upcase
          next if text.empty?

          width = Type.width(text, :dm_mono_medium, 11, 0.08)
          @canvas.put(text, :dm_mono_medium, 11, @bars.center(bucket.index) - (width / 2), 536 + 6 + (0.34 * 11),
                      inks.fetch(@section.labels.axis_tone(bucket)), spacing: 0.08)
        end
      end

      # 11px swatch, the name, the count; then "+N more" for those that do not fit.
      def legend
        rows = tally.totals.counts.select { |repo, n| repo && n.positive? }.sort_by { |repo, n| [ -n, repo ] }
                    .map { |repo, n| [ tally.projects.find(repo), n ] }
        shown = rows.size
        shown -= 1 while shown.positive? && legend_width(rows, shown) > LEGEND_WIDTH
        x = Footnotes::L
        rows.first(shown).each { |project, n| x = legend_item(project, n, x) + LEGEND_GAP }
        return if shown == rows.size

        @canvas.put("+#{rows.size - shown} more", :inter_regular, 13, x - (shown.zero? ? LEGEND_GAP : 0), baseline(13, :inter),
                    @palette[:muted])
      end

      def legend_item(project, n, x)
        @layout.fill(Shapes.rounded(x, LEGEND_TOP + 3.5, 11, 11, 3), project_color(project.rank))
        x = @canvas.put(project.name, :inter_medium, 13, x + 19, baseline(13, :inter), @palette[:ink])
        @canvas.put(n.to_s, :dm_mono_regular, 12, x + 8, baseline(12, :mono), @palette[:muted])
      end

      def legend_width(rows, shown)
        items = rows.first(shown).sum { |project, n| item_width(project, n) } + (LEGEND_GAP * [ shown - 1, 0 ].max)
        return items if shown == rows.size

        items + (shown.zero? ? 0 : LEGEND_GAP) + Type.width("+#{rows.size - shown} more", :inter_regular, 13)
      end

      def item_width(project, n)
        11 + 8 + Type.width(project.name, :inter_medium, 13) + 8 + Type.width(n.to_s, :dm_mono_regular, 12)
      end

      # In the legend's 18px line.
      def baseline(size, family)
        LEGEND_TOP + 9 + ((family == :mono ? 0.34 : Footnotes::INTER_BASE) * size)
      end
    end
  end
end
