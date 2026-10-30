# Analytics' first paint, which works without its script: the switch above
# its panels links to the other set, and every other link keeps the set
# shown.
module AnalyticsHelper
  # The panels under the chart, by their param, each named as the numbers'
  # group of the same place: the websites' first, which analytics opens on
  # and its URL leaves out.
  PANELS = { "websites" => "On your websites", "openstage" => "On Openstage" }.freeze

  # Analytics' address for its view with some params changed: the chart
  # filter's (chart_params), and the panels, kept unless changed.
  def analytics_view_path(view, panels:, **changes)
    shown = changes.delete(:panels) || panels
    params = chart_params(view, default_range: Progress::Window::DEFAULT, **changes)
    analytics_path(params.merge(panels: (shown unless shown == PANELS.keys.first)).compact)
  end
end
