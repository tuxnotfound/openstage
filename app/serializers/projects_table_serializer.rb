# The table under a chart filter's chart: a row per project (per page on
# analytics), a column per number, each cell the row's value over the window
# (and on analytics its change against the window before), and a row's box
# drawing it on the chart or not. On the builder's dashboard a row also has
# Edit, whether their page lists it, and the path that saves its switches:
# each cell's switch sets what visitors see (a value they do not see stays
# for the builder, in grey), or Set up stands where a project counts no site
# visits; a project hidden from the page comes last, with no box.
class ProjectsTableSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper
  include Rails.application.routes.url_helpers

  # chart: a Progress::ChartService or an Analytics::ReportService; changes:
  # whether each cell carries its change.
  def initialize(chart, changes: false)
    @chart = chart
    @changes = changes
  end

  def attributes
    { columns: @chart.columns.map { |number| { key: number.key, label: number.label, word: number.word } },
      rows: @chart.rows.map { |row| row_of(row) } + @chart.off_page.map { |repo| off_page_row(repo) } }
  end

  private

  def row_of(row)
    { repo: row.key, name: row.name, rank: row.rank, on: row.on, drawable: true,
      cells: @chart.columns.map { |number| cell(row, number) } }.merge(builder_parts(row.repo))
  end

  def off_page_row(repo)
    { repo: repo.full_name, name: repo.name, rank: nil, on: false, drawable: false,
      cells: @chart.columns.map { |number| { key: number.key, value: nil, shown: false, pick: nil, setup: nil, change: nil } } }.merge(builder_parts(repo))
  end

  # pick: the cell's switch, on while visitors see the number, for a number
  # the project counts; nil without one.
  def cell(row, number)
    key = number.key
    listed = row.shows?(key) || (@chart.builder && row.counts?(key))
    value = @chart.value(number, row) if listed
    { key: key, value: (number_with_delimiter(value) if listed), shown: row.shows?(key),
      pick: (row.repo.shows?(key) if @chart.builder && row.repo && row.counts?(key)), setup: setup(row, key),
      change: (change(value, number, row) if @changes && row.shows?(key)) }
  end

  def change(value, number, row)
    Progress::Change.of(value, @chart.previous(number, [ row ]))&.to_h
  end

  def setup(row, key)
    return unless @chart.builder && row.repo && key == "visits" && !row.counts?(key)

    edit_project_path(row.repo, site: "open", anchor: "site-visits")
  end

  # A project with no synced repo behind it has nothing to edit or save.
  def builder_parts(repo)
    return { edit: nil, page: nil, switch: nil } unless @chart.builder && repo

    { edit: edit_project_path(repo), page: { on: repo.included?, path: github_repo_path(repo) }, switch: project_numbers_path(repo) }
  end
end
