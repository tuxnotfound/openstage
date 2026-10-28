# The table under a chart filter's chart: a row per project (per page on
# analytics), a column per number, each cell the row's value over the window
# (and on analytics its change against the window before), and a row's box
# drawing it on the chart or not. On the builder's dashboard (manage) a row
# also has Edit, whether their page lists it, and the path that saves its
# switches: each cell's switch sets what visitors see (a value they do not
# see stays for the builder, in grey), or in its place Set up, where a
# project counts no site visits, or Paused, where Free counts another
# project's, each to the project's Site visits row; a project hidden from
# the page comes last, with no box. A project past the palette has no
# colour, so no box: it keeps its values, in grey, as it draws no line.
# Which cells list a value, a switch or a link is the chart's to say
# (DrawService#cells); this only writes it.
class ProjectsTableSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper
  include Rails.application.routes.url_helpers

  # chart: a Progress::ChartService or an Analytics::ReportService; changes:
  # whether each cell carries its change; manage: the builder's own table;
  # off_page: the GithubRepos hidden from their page.
  def initialize(chart, changes: false, manage: false, off_page: [])
    @chart = chart
    @changes = changes
    @manage = manage
    @off_page = off_page
  end

  def attributes
    { columns: @chart.columns.map { |number| { key: number.key, label: number.label, word: number.word } },
      rows: @chart.rows.map { |row| row_of(row) } + @off_page.map { |repo| off_page_row(repo) } }
  end

  private

  # color_class: the class its box wears; nil for a row with no box.
  # drawable: whether it has one; on: whether the chart draws it.
  def row_of(row)
    drawable = row.color_class.present?
    { key: row.key, name: row.name, color_class: row.color_class, on: drawable && row.on, drawable: drawable,
      cells: @chart.cells(row).map { |cell| cell_of(cell, row.repo) } }.merge(manage_parts(row.repo))
  end

  def off_page_row(repo)
    { key: repo.full_name, name: repo.name, color_class: nil, on: false, drawable: false,
      cells: @chart.columns.map { |number| { key: number.key, value: nil, shown: false, pick: nil, link: nil, change: nil } } }.merge(manage_parts(repo))
  end

  # pick: the cell's switch, on while visitors see the number; nil without
  # one. link: what stands in its place, "set_up" or "paused", and where it goes.
  def cell_of(cell, repo)
    { key: cell.number.key, value: (number_with_delimiter(cell.value) if cell.value), shown: cell.shown, pick: cell.pick,
      link: (cell.link && { kind: cell.link.to_s, path: edit_project_path(repo, site: "open", anchor: "site-visits") }),
      change: (Progress::Change.of(cell.value, cell.previous)&.to_h if @changes && cell.shown) }
  end

  # A project with no synced repo behind it has nothing to edit or save.
  def manage_parts(repo)
    return { edit: nil, page: nil, switch: nil } unless @manage && repo

    { edit: edit_project_path(repo), page: { on: repo.included?, path: github_repo_path(repo) }, switch: project_numbers_path(repo) }
  end
end
