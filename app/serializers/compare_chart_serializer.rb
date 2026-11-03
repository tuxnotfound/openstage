# A chart filter's chart as the browser draws it (ProgressChart::Compare),
# from the object the server's chart partial renders (charts/_chart): each
# line with its project, the class of its colour and its number, which the
# browser gives its line style; the gridlines and the axis; a tooltip per
# point, a row per project and a column per tip: each number with lines,
# then any that sits beside it, which has none (line); the marks of the
# entries shipped and published (ProgressChart::Marks); and the note, nil
# unless a number drawn has no line.
class CompareChartSerializer < ApplicationSerializer
  def initialize(chart)
    @chart = chart
  end

  def attributes
    {
      paths: @chart.paths.map { |d, color_class, number, key| { d: d, color_class: color_class, number: number, key: key } },
      ticks: @chart.ticks.map { |tick| { value: tick.value, top: tick.top } },
      columns: @chart.columns.map { |column| column_of(column) }, tips: tips, axis: @chart.axis, marks: @chart.marks.map { |mark| mark_of(mark) },
      aria_label: @chart.aria_label, note: @chart.note, none: @chart.none, indexed: @chart.indexed?
    }
  end

  private

  def column_of(column)
    { left: column.left, width: column.width, mark: column.mark, title: column.title,
      rows: column.rows.map { |row| { key: row.repo, name: row.name, color_class: row.color_class, values: row.values } } }
  end

  # Its entries newest first, each kind and day as What shipped writes them;
  # label: the newest, for a screen reader, with how many more.
  def mark_of(mark)
    entries = mark.items.map { |item| { id: item.id, title: item.title, shipped: item.shipped?, kind: kind_of(item), date: item.date.strftime("%b %-d") } }
    { key: mark.key, number: mark.number, color_class: mark.color_class, column: mark.column, left: mark.left, top: mark.top,
      shipped: mark.shipped?, label: label_of(entries), entries: entries }
  end

  def kind_of(item)
    item.shipped? ? "Shipped" : "Published"
  end

  def label_of(entries)
    newest = entries.first
    "#{newest[:kind]}: #{newest[:title]}, #{newest[:date]}#{", and #{entries.size - 1} more" if entries.size > 1}"
  end

  # line: whether it has lines, so the tooltip heads it with its sample.
  def tips
    @chart.tips.map { |number| { key: number.key, label: number.label, line: @chart.lined.include?(number) } }
  end
end
