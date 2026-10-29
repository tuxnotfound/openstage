module ProgressChart
  # Project colours on the progress section and its cards, by all-time rank
  # (Progress::Projects), so a project keeps its colour everywhere. The first
  # six passed the colourblind check of the 2026-10-15 design round; the
  # first was darkened on 2026-10-23 so white text on it holds 4.5:1. The
  # seventh and eighth are the dataviz reference palette's violet and red,
  # the ninth and tenth were picked with its validator (2026-10-28), and all
  # ten pass its hard gates on the panel in both modes. A project ranked past
  # them has no colour until more colours come: it draws no line and wears no
  # mark, except where it stands alone (alone_class). Text never wears a
  # project colour.
  module Palette
    PROJECT_COLORS = {
      light: %w[#2f6ee0 #eb6834 #1baf7a #eda100 #e87ba4 #008300 #6250d6 #e34948 #9e8eff #7c3856],
      dark: %w[#3987e5 #d95926 #199e70 #c98500 #d55181 #008300 #9085e9 #e66767 #5f4bb4 #8b4664]
    }.freeze
    # The class of marks that wear ink: the builder's own page on analytics,
    # which is no project, and a project past the palette where it stands
    # alone.
    INK_CLASS = "os-project-none".freeze

    module_function

    # Whether marks of a rank wear a colour: each project up to the palette's
    # size, and no project (nil), which wears ink. A project past the palette
    # has none, so no box and no line.
    def colored?(rank)
      rank.nil? || rank < PROJECT_COLORS[:light].size
    end

    # The class that gives a project's marks its colour on the pages
    # (bg-(--project), stroke-(--project), text-(--on-project)): by rank, and
    # ink for no project; nil past the palette.
    def project_class(rank)
      return INK_CLASS if rank.nil?

      "os-project-#{rank + 1}" if colored?(rank)
    end

    # The class of a project's marks where it stands alone, on its own page
    # and its card: its colour, or ink past the palette, as nothing beside it
    # needs telling apart.
    def alone_class(rank)
      project_class(rank) || INK_CLASS
    end

    # A project's colour by rank on a light page: emails and share cards,
    # which cannot follow dark mode. nil for no project, and past the palette.
    def project_color(rank)
      PROJECT_COLORS[:light][rank] if rank
    end

    # Text on a colour in an email: dark when its luminance is over 0.2,
    # which for each light colour picks as the page's --color-on-project
    # tokens do.
    def ink_on(hex)
      luminance(hex) > 0.2 ? "#111111" : "#FFFFFF"
    end

    # A colour's relative luminance, as WCAG's contrast ratio reads it.
    def luminance(hex)
      channels = [ 1, 3, 5 ].map { |i| hex[i, 2].to_i(16) / 255.0 }
      linear = channels.map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
      (0.2126 * linear[0]) + (0.7152 * linear[1]) + (0.0722 * linear[2])
    end
  end
end
