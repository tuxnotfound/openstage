module CardLayout
  class Journey
    # The Journey card's chart: gridlines, the wash, each project's line and
    # the ink total over them, the circles, the end dot and its label, the
    # axes, and the flags with their poles; or one quiet line when the period
    # holds no entries.
    class Plot
      PROJECT_LINE = 2.5
      TOTAL_LINE = 1.75
      FILTERED_LINE = 2.5

      def initialize(layout)
        @layout = layout
        @canvas = layout.canvas
        @palette = layout.palette
        @geometry = layout.geometry
      end

      def draw
        grid
        lines
        markers
        end_mark
        axis
        @layout.flags.each { |flag| flag_text(flag) }
        quiet if @layout.section.tally.items.empty?
      end

      private

      def grid
        scale = @geometry.scale
        scale.ticks.drop(1).each do |value|
          @canvas.draw(:rules, "M#{Geometry::LEFT},#{num(scale.y(value).round(1))}H#{Geometry::RIGHT}")
        end
        scale.ticks.each do |value|
          @canvas.put_end(value.to_s, :dm_mono_regular, 11, 88, scale.y(value) + (0.34 * 11), @palette[:faint])
        end
        @canvas.draw(:rules_strong, "M#{Geometry::LEFT},#{Geometry::BASE}H#{Geometry::RIGHT}")
      end

      def lines
        projects = @layout.section.tally.projects
        @geometry.project_lines.sort_by { |repo, _points| -(projects.find(repo)&.rank || 99) }.each do |repo, points|
          @layout.stroke(path(points), ProgressChart::Palette.project_color(projects.find(repo)&.rank, @layout.theme.to_sym), PROJECT_LINE)
        end
        @layout.stroke(path(@geometry.line), @palette[:ink], @layout.section.project ? FILTERED_LINE : TOTAL_LINE)
        @layout.flags.each do |flag|
          @canvas.draw(:poles, "M#{num(flag.pole_x)},#{num(flag.pole_bottom)}V#{num(flag.pole_top)}")
        end
      end

      def path(points)
        Geometry.path(points)
      end

      # Shipped is a filled circle, published a ring; both keep a halo.
      def markers
        @geometry.markers.each do |marker|
          @canvas.draw(:halos, circle(marker.x, marker.y, Flags::RADIUS + Flags::HALO))
          if marker.shipped
            @canvas.draw(:ship, circle(marker.x, marker.y, Flags::RADIUS))
          else
            @canvas.draw(:ring_fill, circle(marker.x, marker.y, 6.2))
            @canvas.draw(:rings, circle(marker.x, marker.y, 6.2))
          end
        end
      end

      def end_mark
        ex, ey = @geometry.line.last
        @canvas.draw(:halos, circle(ex, ey, Flags::END_DOT + Flags::HALO))
        @canvas.draw(:end_dot, circle(ex, ey, Flags::END_DOT))
        box = @geometry.end_box
        baseline = box.y + (box.h / 2.0) + (INTER_BASE * 24)
        x = @canvas.put(box.num, :inter_semibold, 24, box.x, baseline, @palette[:ink])
        # SVG drops a leading space, so the space before "commits" is an advance.
        @canvas.put(box.word.strip, :inter_regular, 17, x + Type.width(" ", :inter_regular, 17), baseline, @palette[:muted])
      end

      def axis
        Axis.new(@geometry, @layout.section.tally.period).labels.each do |label|
          width = Type.width(label.text, :dm_mono_medium, 11, 0.08)
          @canvas.put(label.text, :dm_mono_medium, 11, label.x - (width / 2), 578, label.today ? @palette[:ink] : @palette[:faint],
                      spacing: 0.08)
        end
      end

      def flag_text(flag)
        face = Flags::FACES.fetch(flag.weight)
        ink = flag.item.shipped? || flag.item.pinned? ? @palette[:ink] : @palette[:muted]
        flag.shape.lines.each_with_index do |line, i|
          baseline = flag.y + (i * Flags::LEADING) + (Flags::LEADING / 2.0) + (INTER_BASE * Flags::SIZE)
          run = i == flag.shape.lines.size - 1 ? flag.shape.run : ""
          gap = run.empty? ? 0 : Type.width(" ", face, Flags::SIZE)
          width = Type.width(line, face, Flags::SIZE) + gap + (run.empty? ? 0 : Type.width(run, :inter_regular, Flags::SIZE))
          x = flag.side == :left ? flag.x + flag.shape.w - width : flag.x
          x = @canvas.put(line, face, Flags::SIZE, x, baseline, ink)
          @canvas.put(run, :inter_regular, Flags::SIZE, x + gap, baseline, @palette[:muted]) unless run.empty?
        end
      end

      # At the plot's top left, or above the top tick when the line climbs there.
      def quiet
        section = @layout.section
        text = section.filtered? ? section.labels.empty_tagged(section.selection_name(alternatives: true), yet: true) : section.labels.empty
        width = Type.width(text, :inter_medium, 20)
        top = [ 328, 288 ].find do |candidate|
          low = candidate + 24 + 3
          (0..((width + 3) / 3).floor).none? { |k| (y = @geometry.line_y(Geometry::LEFT + (k * 3))) && y < low }
        end || 288
        @canvas.put(text, :inter_medium, 20, Geometry::LEFT, top + 12 + (INTER_BASE * 20), @palette[:muted])
      end

      def circle(cx, cy, r)
        Shapes.rounded(cx - r, cy - r, 2 * r, 2 * r, r)
      end

      def num(value)
        Shapes.num(value)
      end
    end
  end
end
