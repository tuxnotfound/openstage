module ProgressChart
  # Project colors on the progress section and its cards, by all-time rank
  # (Progress::Projects), so a project keeps its color everywhere. The six
  # passed the colorblind check of the 2026-10-15 design round; the seventh
  # project and later are gray. Text never wears a project color.
  module Palette
    PROJECT_COLORS = {
      light: %w[#2a78d6 #eb6834 #1baf7a #eda100 #e87ba4 #008300],
      dark: %w[#3987e5 #d95926 #199e70 #c98500 #d55181 #008300]
    }.freeze
    GRAY = { page: "#9CA3AF", light: "#8A8E86", dark: "#6B7378" }.freeze

    module_function

    # surface: :page, or a card's :light or :dark.
    def project_color(rank, surface = :page)
      colors = PROJECT_COLORS[surface == :dark ? :dark : :light]
      rank && rank < colors.size ? colors[rank] : GRAY.fetch(surface)
    end
  end
end
