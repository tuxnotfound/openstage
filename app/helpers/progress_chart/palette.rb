module ProgressChart
  # Project colors on the progress section and its cards, by all-time rank
  # (Progress::Projects), so a project keeps its color everywhere. The first
  # six passed the colorblind check of the 2026-10-15 design round; the first
  # was darkened on 2026-10-23 so white text on it holds 4.5:1. The seventh
  # and eighth are the dataviz reference palette's violet and red, the ninth
  # and tenth were picked with its validator (2026-10-28), and all ten pass
  # its hard gates on the panel in both modes. The eleventh project and later
  # are gray. Text never wears a project color.
  module Palette
    PROJECT_COLORS = {
      light: %w[#2f6ee0 #eb6834 #1baf7a #eda100 #e87ba4 #008300 #6250d6 #e34948 #9e8eff #7c3856],
      dark: %w[#3987e5 #d95926 #199e70 #c98500 #d55181 #008300 #9085e9 #e66767 #5f4bb4 #8b4664]
    }.freeze
    GRAY = { page: "#8A8F98", light: "#8A8E86", dark: "#6B7378" }.freeze
    # The class of marks with no project, which wear ink: the builder's own
    # page on analytics.
    INK = "os-project-none".freeze

    module_function

    # The class that gives a project's marks its colour on the pages
    # (bg-(--project), stroke-(--project), text-(--on-project)): by rank, the
    # 11th project on grey, and ink for no project.
    def project_class(rank)
      return INK if rank.nil?

      rank < PROJECT_COLORS[:light].size ? "os-project-#{rank + 1}" : "os-project-other"
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

    # surface: :page, or a card's :light or :dark.
    def project_color(rank, surface = :page)
      colors = PROJECT_COLORS[surface == :dark ? :dark : :light]
      rank && rank < colors.size ? colors[rank] : GRAY.fetch(surface)
    end
  end
end
