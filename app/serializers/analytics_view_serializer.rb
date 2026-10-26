# The Pro analytics page for one window, the pages picked and the number
# charted, as the page shows it. The page renders it first and its script asks
# for others (Api::AnalyticsController).
class AnalyticsViewSerializer < ApplicationSerializer
  include AnalyticsHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper

  METRICS = Analytics::CountService::METRICS

  def initialize(report)
    @report = report
  end

  def attributes
    chart = ProgressChart::Visits.new(@report)
    {
      range: window.range, metric: @report.metric, selected: everything? ? [] : @report.selected.map(&:key),
      everything: everything?, window_label: window.label, words: window.words,
      pages: @report.pages.map { |page| page_switch(page) },
      tabs: METRICS.map { |metric| tab(metric) }, label: chart.name, scope: scope, change_label: change_label,
      total: number(@report.total(@report.metric)), change: change(@report.change(@report.metric)),
      chart: ChartSerializer.new(chart).attributes, sources: sources, countries: countries, rows: rows, links: links, badges: badges
    }
  end

  private

  def window
    @report.window
  end

  def everything?
    @report.selected.size == @report.pages.size
  end

  def scope
    everything? ? "all pages" : @report.selected.map(&:name).to_sentence
  end

  # value: the number charted, on that page, while it is in view.
  def page_switch(page)
    on = @report.selected.include?(page)
    { key: page.key, name: page.name, rank: page.rank, on: on, value: (number(@report.total(@report.metric, page: page)) if on) }
  end

  def tab(metric)
    { metric: metric, label: ProgressChart::Visits::LABELS.fetch(metric), group: ProgressChart::Visits::GROUPS.fetch(metric),
      value: number(@report.total(metric)), change: change(@report.change(metric)) }
  end

  # arrow, text and up?, as the page writes a change; nils with nothing to compare.
  def change(percent)
    arrow, text, up = analytics_change(percent)
    { arrow: arrow, text: text, up: up }
  end

  def sources
    most = @report.sources.first&.last.to_i
    @report.sources.map { |label, count| { label: label, count: number(count), width: (100.0 * count / most).round } }
  end

  def countries
    @report.countries.map { |label, count| { label: label, count: number(count) } }
  end

  # The table's last column: the picked number against the days before.
  def change_label
    "#{ProgressChart::Visits::LABELS.fetch(@report.metric)} vs #{window.label} before"
  end

  # The pages picked, busiest in the number picked first, with each number
  # and that number's change.
  def rows
    @report.selected.sort_by { |page| -@report.total(@report.metric, page: page) }.map do |page|
      values = METRICS.map { |metric| @report.total(metric, page: page) }
      { key: page.key, name: page.name, rank: page.rank, values: values.map { |value| value.positive? ? number(value) : "–" },
        change: change(@report.change(@report.metric, page: page)) }
    end
  end

  def links
    @report.links.map { |link| { title: link.title, page: link.page.name, count: number(link.count) } }
  end

  def badges
    @report.shown.map { |kind, count, sites| { label: kind == "badge" ? "README badge" : "Embed widget", count: number(count), sites: pluralize(sites, "site") } }
  end

  def number(value)
    number_with_delimiter(value)
  end
end
