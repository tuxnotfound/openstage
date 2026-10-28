# A chart filter's first paint on every chart page, which works without the
# chart's script: a number toggle, a window pill and a project's box, Only
# and Show all each link to the view they switch to, and each number wears
# its line. view: a ChartFilterSerializer's attributes.
module ChartFilterHelper
  # A number's line by its place in the line order: solid, dotted, dashed.
  LINE_DASHES = [ nil, "2 9", "14 10" ].freeze
  # The same three as a toggle's or a column's sample.
  KEY_DASHES = [ nil, "0.1 5.5", "7 4.5" ].freeze

  # The view's params with some changed, for a link: the window, the numbers
  # drawn in line order and the projects in view, each left out at the
  # page's default.
  def chart_params(view, default_range:, **changes)
    range = changes.fetch(:range, view[:range])
    show = changes.fetch(:show, view[:drawn])
    projects = changes.fetch(:projects, view[:selected])
    { range: (range unless range == default_range), show: (show.join(",") unless show == view[:default_show]),
      projects: projects.presence&.join(",") }
  end

  # The numbers drawn once a toggle is clicked; nil when the click cannot
  # change them, as the last number drawn stays and three is the most.
  def chart_show_toggled(view, key)
    drawn = view[:drawn]
    if drawn.include?(key)
      drawn - [ key ] if drawn.size > 1
    elsif drawn.size < Progress::DrawService::MAX_DRAWN
      drawn + [ key ]
    end
  end

  # The projects in view once a row's box is clicked, none for all of them;
  # nil when the last one in view would go.
  def chart_projects_toggled(view, repo)
    all = view[:table][:rows].select { |row| row[:drawable] }.pluck(:repo)
    in_view = view[:selected].presence || all
    after = in_view.include?(repo) ? in_view - [ repo ] : all & (in_view + [ repo ])
    return if after.empty?

    after.size == all.size ? [] : after
  end

  # The line a number wears on the first paint: its place among the numbers
  # drawn while the chart compares numbers, else solid.
  def chart_line(view, key)
    view[:chart][:indexed] ? view[:drawn].index(key).to_i : 0
  end

  # The colour of a change's arrow; only the arrow wears it.
  def chart_tone(up)
    { true => "text-up", false => "text-down" }[up]
  end
end
