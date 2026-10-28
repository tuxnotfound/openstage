# A chart filter's view for one window, the numbers drawn and the projects in
# view, as a builder's page, one of their projects' pages or their dashboard
# shows it: a toggle per number its projects show, with its total and how it
# splits across them (and its change, on the dashboard), the one chart, the
# table of projects under it where a page has several, and What shipped. The
# page renders it first and the chart script asks for others
# (Api::ProgressController); the words come from the helpers the page's own
# partials use.
class ProgressViewSerializer < ApplicationSerializer
  include ApplicationHelper
  include ProgressHelper
  include AnalyticsHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper

  # chart: a Progress::ChartService. linked_id: the entry a link pointed at,
  # shown above the page instead.
  def initialize(chart, linked_id: nil)
    @chart = chart
    @linked_id = linked_id
  end

  # drawn: the numbers drawn, in line order; default_show: the page's own,
  # which its URL leaves out.
  def attributes
    @attributes ||= {
      range: labels.range, words: labels.span_words, selected: section.filtered? ? section.selected.map(&:repo) : [],
      numbers: @chart.totals.map { |total| number_of(total) }, drawn: @chart.drawn.map(&:key), default_show: @chart.default_drawn.map(&:key),
      chart: CompareChartSerializer.new(@chart.chart).attributes, table: (ProjectsTableSerializer.new(@chart).attributes if table?),
      shipped: (shipped unless @chart.builder)
    }
  end

  private

  def section
    @chart.section
  end

  def tally
    section.tally
  end

  def labels
    section.labels
  end

  # The dashboard always has its table: it is where the builder picks what
  # visitors see. A page has one with more than one project.
  def table?
    @chart.builder || (!@chart.lone && @chart.rows.size > 1)
  end

  # split: the part of each project in view with any, for the toggle's bar.
  def number_of(total)
    number = total.number
    { key: number.key, label: number.label, word: number.word, value: number_with_delimiter(total.value),
      split: total.split.map { |row, count| { repo: row.key, rank: row.rank, value: count } },
      change: (change(total) if @chart.builder) }
  end

  # arrow, text and up?, as the page writes a change; nil with nothing to compare with.
  def change(total)
    return unless total.previous&.positive?

    arrow, text, up = analytics_change(((100.0 * total.value / total.previous) - 100).round)
    { arrow: arrow, text: text, up: up }
  end

  # Newest first, in the builder's words.
  def shipped
    items = tally.items.reverse
    empty = section.filtered? ? labels.empty_tagged(section.selection_name(alternatives: true)) : labels.empty
    { heading: "#{items.size} #{labels.word}", empty: empty, items: items.map { |item| shipped_item(item) } }
  end

  def shipped_item(item)
    project = item.repo_name && tally.projects.find(item.repo_name)
    { id: item.id, anchor: (item.id == @linked_id ? nil : "entry-#{item.id}"), date: item.date.strftime("%b %-d"),
      kind: item.shipped? ? "Shipped" : "Published", title: item.title, run_in: progress_run_in(item, section).to_s,
      url: safe_external_url(item.entry.url), project: project&.name }
  end
end
