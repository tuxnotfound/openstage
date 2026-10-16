module CardLayout
  # The projects of a progress card's period, busiest first, on one 18px row:
  # a swatch (a square under bars, a short line under lines), the name and its
  # commits, 22px apart, as many as fit and then "+N more". Not drawn under a
  # filter, where the card shows one project.
  class ProgressLegend
    GAP = 22
    BASE = ProgressHeader::INTER_BASE

    # swatch: :square or :line.
    def initialize(layout, top:, width:, swatch:)
      @layout = layout
      @canvas = layout.canvas
      @palette = layout.palette
      @section = layout.section
      @top = top
      @width = width
      @swatch = swatch
    end

    def draw
      return if @section.project

      rows = projects
      shown = rows.size
      shown -= 1 while shown.positive? && width_of(rows, shown) > @width
      x = ProgressHeader::L
      rows.first(shown).each { |project, n| x = item(project, n, x) + GAP }
      return if shown == rows.size

      @canvas.put("+#{rows.size - shown} more", :inter_regular, 13, x - (shown.zero? ? GAP : 0), baseline(13, BASE), @palette[:muted])
    end

    private

    def projects
      tally = @section.tally
      tally.totals.counts.select { |repo, n| repo && n.positive? }.sort_by { |repo, n| [ -n, repo ] }
           .filter_map { |repo, n| (project = tally.projects.find(repo)) && [ project, n ] }
    end

    def item(project, n, x)
      color = ProgressChart::Palette.project_color(project.rank, @layout.theme.to_sym)
      shape = @swatch == :line ? Shapes.rounded(x, @top + 7.5, 14, 3, 1.5) : Shapes.rounded(x, @top + 3.5, 11, 11, 3)
      @layout.fill(shape, color)
      x = @canvas.put(project.name, :inter_medium, 13, x + swatch_width + 8, baseline(13, BASE), @palette[:ink])
      @canvas.put(n.to_s, :dm_mono_regular, 12, x + 8, baseline(12, 0.34), @palette[:muted])
    end

    def swatch_width
      @swatch == :line ? 14 : 11
    end

    def width_of(rows, shown)
      items = rows.first(shown).sum { |project, n| item_width(project, n) } + (GAP * [ shown - 1, 0 ].max)
      return items if shown == rows.size

      items + (shown.zero? ? 0 : GAP) + Type.width("+#{rows.size - shown} more", :inter_regular, 13)
    end

    def item_width(project, n)
      swatch_width + 8 + Type.width(project.name, :inter_medium, 13) + 8 + Type.width(n.to_s, :dm_mono_regular, 12)
    end

    def baseline(size, base)
      @top + 9 + (base * size)
    end
  end
end
