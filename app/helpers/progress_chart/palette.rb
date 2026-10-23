module ProgressChart
  # Project colors on the progress section and its cards, by all-time rank
  # (Progress::Projects), so a project keeps its color everywhere. The six
  # passed the colorblind check of the 2026-10-15 design round; the first was
  # darkened on 2026-10-23 so white text on it holds 4.5:1, and passes again.
  # The seventh project and later are gray. Text never wears a project color.
  module Palette
    PROJECT_COLORS = {
      light: %w[#2f6ee0 #eb6834 #1baf7a #eda100 #e87ba4 #008300],
      dark: %w[#3987e5 #d95926 #199e70 #c98500 #d55181 #008300]
    }.freeze
    GRAY = { page: "#8A8F98", light: "#8A8E86", dark: "#6B7378" }.freeze

    module_function

    # Text on a colour: dark when its luminance is over 0.2, as the page's
    # --color-on-project tokens are.
    def ink_on(hex)
      channels = [ 1, 3, 5 ].map { |i| hex[i, 2].to_i(16) / 255.0 }
      linear = channels.map { |c| c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4 }
      (0.2126 * linear[0]) + (0.7152 * linear[1]) + (0.0722 * linear[2]) > 0.2 ? "#111111" : "#FFFFFF"
    end

    # surface: :page, or a card's :light or :dark.
    def project_color(rank, surface = :page)
      colors = PROJECT_COLORS[surface == :dark ? :dark : :light]
      rank && rank < colors.size ? colors[rank] : GRAY.fetch(surface)
    end
  end
end
