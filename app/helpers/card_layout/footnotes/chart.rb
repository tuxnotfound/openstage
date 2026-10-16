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
        ProgressLegend.new(@layout, top: LEGEND_TOP, width: LEGEND_WIDTH, swatch: :square).draw
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
        inks = { now: @palette[:ink], past: @palette[:faint] }
        tally.period.buckets.each do |bucket|
          text = @section.labels.axis(bucket).upcase
          next if text.empty?

          width = Type.width(text, :dm_mono_medium, 11, 0.08)
          @canvas.put(text, :dm_mono_medium, 11, @bars.center(bucket.index) - (width / 2), 536 + 6 + (0.34 * 11),
                      inks.fetch(@section.labels.axis_tone(bucket)), spacing: 0.08)
        end
      end
    end
  end
end
