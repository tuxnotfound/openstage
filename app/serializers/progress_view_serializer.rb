# The progress section for one window and the projects in view, as the page
# shows it: the number and its change, the colour bar, the project switches, the
# chart and What shipped. The page renders it first and the chart script asks
# for others (Api::ProgressController); the words come from the helpers the
# page's own partials use.
class ProgressViewSerializer < ApplicationSerializer
  include ApplicationHelper
  include ProgressHelper
  include NumbersHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper

  # numbers: the Progress::NumbersService for the section; linked_id: the
  # entry a link pointed at, shown above the page instead; table: the
  # dashboard's DashboardProjectsSerializer.
  def initialize(section, numbers:, linked_id: nil, table: nil)
    @section = section
    @numbers = numbers.numbers
    @linked_id = linked_id
    @table = table
  end

  def attributes
    totals = tally.totals
    arrow, words, up = progress_change(@section)
    {
      range: @section.labels.range, selected: @section.selected.map(&:repo), filtered: @section.filtered?,
      words: @section.labels.words, scope: progress_scope(@section), commits: totals.commits,
      change: { arrow: arrow, words: words.presence, up: up }, shares: shares, kpis: kpis,
      projects: tally.projects.all.map { |project| project_switch(project) },
      numbers: @numbers.map { |number| number_of(number) }, shipped: shipped, table: @table&.attributes
    }
  end

  private

  def tally
    @section.tally
  end

  def shares
    totals = tally.totals
    tally.projects.all.filter_map do |project|
      commits = totals.counts[project.repo].to_i
      next unless commits.positive?

      { repo: project.repo, name: project.name, rank: project.rank, commits: commits, percent: (100.0 * commits / totals.commits).round }
    end
  end

  def kpis
    totals = tally.totals
    "#{totals.shipped} shipped · #{totals.published} published · #{pluralize(totals.projects, 'project')} with commits · " \
      "#{pluralize(totals.active_days, 'active day')}"
  end

  # value: the first number charted, for the project, while it is in view.
  def project_switch(project)
    on = !@section.filtered? || @section.selected.include?(project)
    first = @numbers.find(&:chart)
    { repo: project.repo, name: project.name, rank: project.rank, on: on,
      value: (pluralize(number_with_delimiter(first.by_project.fetch(project.repo, 0)), first.unit) if on) }
  end

  # Every number with its total and change; the charted ones with their chart.
  def number_of(number)
    arrow, words, up = number_change(number, @section)
    { key: number.key, label: number.label, value: number_with_delimiter(number.total), change: { arrow: arrow, words: words.presence, up: up },
      on: number.chart.present?, chart: (ChartSerializer.new(number.chart).attributes if number.chart) }
  end

  # Newest first, in the builder's words.
  def shipped
    items = tally.items.reverse
    empty = @section.filtered? ? @section.labels.empty_tagged(@section.selection_name(alternatives: true)) : @section.labels.empty
    { heading: "#{items.size} #{@section.labels.word}", empty: empty, items: items.map { |item| shipped_item(item) } }
  end

  def shipped_item(item)
    project = item.repo_name && tally.projects.find(item.repo_name)
    { id: item.id, anchor: (item.id == @linked_id ? nil : "entry-#{item.id}"), date: item.date.strftime("%b %-d"),
      kind: item.shipped? ? "Shipped" : "Published", title: item.title, run_in: progress_run_in(item, @section).to_s,
      url: safe_external_url(item.entry.url), project: project&.name }
  end
end
