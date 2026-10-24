# A chart as the browser draws it: the lines, gridlines, axis and tooltips the
# server's chart partial renders (profiles/page/_chart), from the same object,
# so a chart's geometry is worked out in one place. chart: a
# ProgressChart::Trend or ProgressChart::Visits.
class ChartSerializer < ApplicationSerializer
  def initialize(chart)
    @chart = chart
  end

  def attributes
    {
      paths: @chart.paths.map { |d, rank| { d: d, rank: rank } },
      ticks: @chart.ticks.map { |tick| { value: tick.value, top: tick.top } },
      columns: @chart.columns.map { |column| column_of(column) },
      axis: @chart.axis, aria_label: @chart.aria_label, note: @chart.note, empty_note: @chart.empty_note, none: @chart.none,
      empty: @chart.lines.empty?, average: @chart.average?, legend: @chart.lines.map { |line| { name: line.name, rank: line.rank } }
    }
  end

  private

  def column_of(column)
    { left: column.left, width: column.width, mark: column.mark, title: column.title,
      rows: column.rows.map { |row| { name: row.name, rank: row.rank, value: row.value.to_s } } }
  end
end
