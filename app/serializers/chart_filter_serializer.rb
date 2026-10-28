# A chart filter's view for one window, the numbers drawn and the rows in
# view, as every chart page shows it: a toggle per number its rows show, with
# its total for the rows in view, how that splits across them and, where the
# page shows changes, its change against the window before; the numbers
# drawn; the one chart; and the table of rows under it. filter: a
# Progress::ChartService or an Analytics::ReportService.
class ChartFilterSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper

  # changes: whether the toggles carry their change; table: whether the view
  # has its table; cell_changes: whether its cells carry theirs too.
  def initialize(filter, changes:, table:, cell_changes: false)
    @filter = filter
    @changes = changes
    @table = table
    @cell_changes = cell_changes
  end

  # selected: the rows in view, none for all of them; drawn: the numbers
  # drawn, in line order; default_show: the page's own, which its URL leaves out.
  def attributes
    labels = @filter.period.labels
    {
      range: labels.range, words: labels.span_words, selected: @filter.selected_keys,
      numbers: @filter.totals.map { |total| number_of(total) }, drawn: @filter.drawn.map(&:key), default_show: @filter.default_drawn.map(&:key),
      chart: CompareChartSerializer.new(@filter.chart).attributes,
      table: (ProjectsTableSerializer.new(@filter, changes: @cell_changes).attributes if @table)
    }
  end

  private

  # group: where it happens, for the toggles grouped under it; value: "–"
  # when no row in view shows it; split: the part of each row in view with
  # any, for the toggle's bar.
  def number_of(total)
    number = total.number
    { key: number.key, label: number.label, word: number.word, group: number.group, value: total.value ? number_with_delimiter(total.value) : "–",
      split: total.split.map { |row, count| { repo: row.key, rank: row.rank, value: count } },
      change: (Progress::Change.of(total.value, total.previous)&.to_h if @changes) }
  end
end
