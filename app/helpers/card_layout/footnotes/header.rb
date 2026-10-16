module CardLayout
  class Footnotes
    # Who, at the top: the name, Pro and the handle beside the avatar, the
    # page's address at the right. Then the period over the chart: its tag,
    # its title and a dateline with the commits and active days.
    class Header
      LINK_SPACING = -0.005

      def initialize(layout)
        @layout = layout
        @canvas = layout.canvas
        @palette = layout.palette
        @section = layout.section
      end

      def draw
        identity
        link
        period
      end

      private

      def user
        @layout.user
      end

      def identity
        name_end = @canvas.put(CardText.clean(user.display_name.to_s), :inter_semibold, 26, 132, line(52, 30, 26), @palette[:ink],
                               spacing: -0.01)
        pro(name_end + 10) if user.pro?
        @canvas.put("@#{user.username}", :dm_mono_regular, 14, 132, line(88, 18, 14, mono: true), @palette[:muted])
      end

      def pro(x)
        width = Type.width("PRO", :dm_mono_medium, 10.5, 0.12) + (0.12 * 10.5) + 12 + 2
        @canvas.draw(:chip, Shapes.outline(x, 57, width, 20, 4))
        @canvas.put("PRO", :dm_mono_medium, 10.5, x + 7, line(57, 20, 10.5, mono: true), @palette[:muted], spacing: 0.12)
      end

      def link
        baseline = line(70, 20, 16)
        start = @canvas.put_end(user.username.to_s, :inter_medium, 16, R, baseline, @palette[:ink], spacing: LINK_SPACING)
        @canvas.put_end("openstage.dev/", :inter_medium, 16, start - (LINK_SPACING * 16), baseline, @palette[:muted],
                        spacing: LINK_SPACING)
      end

      def period
        labels = @section.labels
        @canvas.put(labels.tag, :dm_mono_medium, 12, L, line(166, 14, 12, mono: true), @palette[:accent], spacing: 0.14)
        @canvas.put(labels.title, :inter_semibold, 46, 58, line(184, 54, 46), @palette[:ink], spacing: -0.02)
        dateline
      end

      # "Jan 1 – Oct 15, so far · 380 commits on 64 days", led by the project
      # under a filter.
      def dateline
        baseline = line(244, 20, 16)
        x = L
        if (project = @section.project)
          @canvas.dot(L + 5, 254, 5, ProgressChart::Palette.project_color(project.rank, @layout.theme.to_sym))
          x = @canvas.put(project.name, :inter_medium, 16, L + 18, baseline, @palette[:ink])
          space = Type.width(" ", :inter_regular, 16)
          x = @canvas.put("·", :inter_regular, 16, x + space, baseline, @palette[:muted]) + space
        end
        @canvas.put(dateline_text, :inter_regular, 16, x, baseline, @palette[:muted])
      end

      def dateline_text
        totals = @section.tally.totals
        "#{@section.labels.subtitle.sub(' · so far', ', so far')} · #{totals.commits} #{'commit'.pluralize(totals.commits)} " \
          "on #{totals.active_days} #{'day'.pluralize(totals.active_days)}"
      end

      # The baseline of a line of text set in a CSS box at top, this high.
      def line(top, height, size, mono: false)
        top + (height / 2.0) + ((mono ? 0.34 : INTER_BASE) * size)
      end
    end
  end
end
