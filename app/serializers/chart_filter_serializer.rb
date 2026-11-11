# A chart filter's view for one window, the numbers drawn and the rows in
# view, as every chart page shows it: a toggle per number its rows show that
# the chart can draw (Progress::DrawService#totals), with its total for the
# rows in view, how that splits across them and, where the page shows
# changes, its change against the window before; the numbers drawn; the one
# chart; and the table of rows under it. filter: a Progress::ChartService or
# an Analytics::ReportService.
class ChartFilterSerializer < ApplicationSerializer
  # changes: whether the toggles carry their change; table: the
  # ProjectsTableSerializer of the rows under the chart, nil without one.
  def initialize(filter, changes:, table: nil)
    @filter = filter
    @changes = changes
    @table = table
  end

  # selected: the rows in view, none for all of them; drawn: the numbers
  # drawn, in line order; default_show: the page's own, which its URL leaves
  # out; calendar: what the window's calendar offers (calendar).
  def attributes
    labels = @filter.totals_window.labels
    {
      range: labels.range, words: labels.span_words, calendar: calendar(labels), selected: @filter.selected_keys,
      numbers: @filter.totals.map { |total| number_of(total) }, drawn: @filter.drawn.map(&:key), default_show: @filter.default_drawn.map(&:key),
      chart: CompareChartSerializer.new(@filter.chart).attributes,
      table: @table&.attributes
    }
  end

  private

  # today, in the builder's zone, and earliest, the first day anything here
  # counted (nil with none), bound the days it offers; picked: the days
  # picked on screen, with their name for the window's pill, nil for the
  # other windows.
  def calendar(labels)
    window = @filter.totals_window
    picked = window.picked
    { today: window.today.iso8601, earliest: @filter.earliest&.iso8601,
      picked: (picked && { from: picked.from.iso8601, to: picked.to.iso8601, name: labels.name }) }
  end

  # The one part of a toggle's bar that the rows past the palette share.
  OTHERS = "others".freeze

  # group: where it happens, for the toggles grouped under it; value: "–"
  # when no row in view shows it; split: the part of each row in view with
  # any, in the class of its colour, for the toggle's bar, and one empty
  # share for the rows past the palette together (OTHERS), so a builder with
  # hundreds of projects keeps a bar that fits its toggle.
  def number_of(total)
    number = total.number
    { key: number.key, label: number.label, word: number.word, group: number.group, value: total.value ? @filter.counts.written(number, total.value) : "–",
      split: split_of(total), change: (Progress::Change.of(total.value, total.previous)&.to_h if @changes) }
  end

  def split_of(total)
    colored, others = total.split.partition { |row, _| row.color_class }
    parts = colored.map { |row, count| { key: row.key, color_class: row.color_class, value: count } }
    others.any? ? parts << { key: OTHERS, color_class: nil, value: others.sum(&:last) } : parts
  end
end
