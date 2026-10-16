module CardLayout
  # The top of both progress cards: the name, Pro and the handle beside the
  # avatar, the page's address at the right. Then the period: its tag, its
  # title and a dateline under it, led by the project under a filter.
  class ProgressHeader
    LINK_SPACING = -0.005
    L = 60
    R = 1140
    # Inter's baseline sits this far below the middle of its line box, in ems;
    # DM Mono's at 0.34. Measured in Chrome, so the mocks' CSS boxes land.
    INTER_BASE = 0.364

    # dateline: the words after the project; dot: the project dot's diameter.
    def initialize(layout, dateline:, dot:)
      @layout = layout
      @canvas = layout.canvas
      @palette = layout.palette
      @section = layout.section
      @dateline = dateline
      @dot = dot
    end

    # The baseline of a line of text set in a CSS box at top, this high.
    def self.line(top, height, size, mono: false)
      top + (height / 2.0) + ((mono ? 0.34 : INTER_BASE) * size)
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

    def dateline
      baseline = line(244, 20, 16)
      x = @section.filtered? ? selection(baseline) : L
      @canvas.put(@dateline, :inter_regular, 16, x, baseline, @palette[:muted])
    end

    # The project in view behind its dot, or several by name: the legend
    # gives their colors.
    def selection(baseline)
      x = L
      if (project = @section.project)
        @canvas.dot(L + (@dot / 2.0), 254, @dot / 2.0, ProgressChart::Palette.project_color(project.rank, @layout.theme.to_sym))
        x += @dot + 8
      end
      x = @canvas.put(@section.selection_name, :inter_medium, 16, x, baseline, @palette[:ink])
      space = Type.width(" ", :inter_regular, 16)
      @canvas.put("·", :inter_regular, 16, x + space, baseline, @palette[:muted]) + space
    end

    def line(...)
      self.class.line(...)
    end
  end
end
