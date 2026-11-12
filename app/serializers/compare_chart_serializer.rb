# A chart filter's chart as the browser draws it (ProgressChart::Compare),
# from the object the server's chart partial renders (charts/_chart): each
# line with its project, the class of its colour, its number, which the
# browser gives its line style, and the point it starts on; the gridlines and
# the axis, each gridline with its value, or each number's on a chart that
# compares them; a tooltip per point, a row per project and a column per tip: each
# number with lines, then any that sits beside it, which has none (line); the
# marks of the entries shipped and published (ProgressChart::Marks); and the
# note (CompareNote).
class CompareChartSerializer < ApplicationSerializer
  def initialize(chart)
    @chart = chart
  end

  def attributes
    {
      paths: @chart.paths.map { |d, color_class, number, key, start| { d: d, color_class: color_class, number: number, key: key, start: start } },
      ticks: @chart.ticks.map { |tick| { value: tick.value, top: tick.top, values: tick.values.map { |key, label| { key: key, label: label } } } },
      columns: @chart.columns.map { |column| column_of(column) }, tips: tips, axis: @chart.axis, marks: @chart.marks.map { |mark| mark_of(mark) },
      aria_label: @chart.aria_label, note: @chart.note, none: @chart.none, indexed: @chart.indexed?
    }
  end

  private

  def column_of(column)
    { left: column.left, width: column.width, mark: column.mark, title: column.title,
      rows: column.rows.map { |row| { key: row.repo, name: row.name, color_class: row.color_class, values: row.values } } }
  end

  # Its entries newest first, each badge in the words and the day What's new
  # writes them with; label: the newest, for a screen reader, with how many
  # more.
  def mark_of(mark)
    entries = mark.items.map do |item|
      { id: item.id, title: item.title, badge: item.badge.to_s, kind: ProgressHelper::BADGE_WORDS.fetch(item.badge), date: item.date.strftime("%b %-d") }
    end
    { key: mark.key, number: mark.number, color_class: mark.color_class, column: mark.column, left: mark.left, top: mark.top,
      badge: mark.badge.to_s, label: label_of(entries), entries: entries }
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
