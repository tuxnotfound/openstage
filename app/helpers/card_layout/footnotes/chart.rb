module CardLayout
  class Footnotes
    # The left column's chart, as the page draws it: bars stacked by project,
    # or each project's commits added up as its own line. Numbered discs mark
    # the buckets holding the notes: on the bars; on a track under the lines,
    # where most entries have no line to stand on; or on the line itself when
    # one project is in view. Then the axes, and as many projects in the
    # legend as fit.
    class Chart
      FRAME = ProgressChart::Bars::Frame.new(left: 96, right: 620, top: 318, bottom: 528)
      # Under every project's line the plot ends higher, leaving room for the track.
      TRACK_FRAME = FRAME.with(bottom: 500)
      TRACK_Y = 522
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
        geometry = lines? ? ProgressChart::Lines : ProgressChart::Bars
        @series = geometry.new(tally.buckets, repos: tally.projects.all.map(&:repo), colors: colors, frame: on_track? ? TRACK_FRAME : FRAME)
        @discs = place(items)
      end

      def draw
        lines? ? lines : @series.fills.each { |path, color| @layout.fill(path, color) }
        axes
        @discs.each { |disc| @layout.disc(disc.x - (disc.width / 2.0), disc.cy - (SHAPE.size / 2.0), disc.width, disc.label, disc.shipped?) }
        ProgressLegend.new(@layout, top: LEGEND_TOP, width: LEGEND_WIDTH, swatch: lines? ? :line : :square).draw
      end

      private

      def lines?
        @layout.kind == :lines
      end

      def on_track?
        lines? && @section.project.nil?
      end

      def place(items)
        project = @section.project
        if lines? && project
          return ProgressChart::Markers.new(items, period: tally.period, lines: @series, repo: project.repo, shape: SHAPE).all
        end

        ground = on_track? ? ProgressChart::Discs.track(@series, tally.buckets.size, TRACK_Y, SHAPE) : @series
        ProgressChart::Discs.new(items, period: tally.period, bars: ground, shape: SHAPE).all
      end

      # The one project's area in its color, the track, the lines, and an open
      # dot where each ends.
      def lines
        project = @section.project
        @layout.wash = [ @series.wash(project.repo), project_color(project.rank) ] if project
        @canvas.draw(:rules, "M#{FRAME.left},#{TRACK_Y + 0.5}H#{FRAME.right}") if on_track?
        @series.paths.each { |path, color| @layout.stroke(path, color, 2.5) }
        ends = @series.ends(3.5)
        @canvas.draw(:end_fill, ends)
        @canvas.draw(:end_ring, ends)
      end

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
        scale = @series.scale
        scale.ticks.drop(1).each do |value|
          @canvas.draw(:rules, "M#{FRAME.left},#{Shapes.num(scale.y(value).round(1) + 0.5)}H#{FRAME.right}")
          @canvas.put_end(value.to_s, :dm_mono_regular, 11, 88, scale.y(value) + (0.34 * 11), @palette[:faint])
        end
        @canvas.draw(:rules_strong, "M#{FRAME.left},#{@series.frame.bottom + 0.5}H#{FRAME.right}")
        axis_labels
      end

      def axis_labels
        inks = { now: @palette[:ink], past: @palette[:faint] }
        tally.period.buckets.each do |bucket|
          text = @section.labels.axis(bucket).upcase
          next if text.empty?

          width = Type.width(text, :dm_mono_medium, 11, 0.08)
          @canvas.put(text, :dm_mono_medium, 11, @series.center(bucket.index) - (width / 2), 536 + 6 + (0.34 * 11),
                      inks.fetch(@section.labels.axis_tone(bucket)), spacing: 0.08)
        end
      end
    end
  end
end
