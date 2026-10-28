# A chart filter's view for one window, the numbers drawn and the projects in
# view, as a builder's page, one of their projects' pages or their dashboard
# shows it (ChartFilterSerializer: the toggles, the chart and, where a page
# has several projects, the table under it; changes on the dashboard alone),
# and What shipped. The page renders it first and the chart script asks for
# others (Api::ProgressController); the words come from the helpers the
# page's own partials use.
class ProgressViewSerializer < ApplicationSerializer
  include ApplicationHelper
  include ProgressHelper

  # chart: a Progress::ChartService. linked_id: the entry a link pointed at,
  # shown above the page instead.
  def initialize(chart, linked_id: nil)
    @chart = chart
    @linked_id = linked_id
  end

  def attributes
    @attributes ||= ChartFilterSerializer.new(@chart, changes: @chart.builder.present?, table: table).attributes
                                         .merge(shipped: (shipped unless @chart.builder))
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
  def table
    return unless @chart.builder.present? || (!@chart.lone && @chart.rows.size > 1)

    ProjectsTableSerializer.new(@chart, manage: @chart.builder.present?, off_page: @chart.off_page)
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
