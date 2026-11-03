# A chart filter's chart as the browser draws it (ProgressChart::Compare),
# from the object the server's chart partial renders (charts/_chart): each
# line with its project, the class of its colour and its number, which the
# browser gives its line style; the gridlines and the axis; a tooltip per
# point, a row per project and a column per tip: each number with lines,
# then any that sits beside it, which has none (line); and the note, nil
# unless a number drawn has no line.
class CompareChartSerializer < ApplicationSerializer
  def initialize(chart)
    @chart = chart
  end

  def attributes
    {
      paths: @chart.paths.map { |d, color_class, number, key| { d: d, color_class: color_class, number: number, key: key } },
      ticks: @chart.ticks.map { |tick| { value: tick.value, top: tick.top } },
      columns: @chart.columns.map { |column| column_of(column) }, tips: tips, axis: @chart.axis,
      aria_label: @chart.aria_label, note: @chart.note, none: @chart.none, indexed: @chart.indexed?
    }
  end

  private

  def column_of(column)
    { left: column.left, width: column.width, mark: column.mark, title: column.title,
      rows: column.rows.map { |row| { key: row.repo, name: row.name, color_class: row.color_class, values: row.values } } }
  end

  # line: whether it has lines, so the tooltip heads it with its sample.
  def tips
    @chart.tips.map { |number| { key: number.key, label: number.label, line: @chart.lined.include?(number) } }
  end
end
