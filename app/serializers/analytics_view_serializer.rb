# The Pro analytics page for one window, the pages picked and the numbers
# charted, as the page shows it: every number with its total and change, the
# charted ones with their chart. The page renders it first and its script
# asks for others (Api::AnalyticsController).
class AnalyticsViewSerializer < ApplicationSerializer
  include AnalyticsHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper

  METRICS = Analytics::CountService::METRICS

  def initialize(report)
    @report = report
  end

  def attributes
    {
      range: window.range, selected: everything? ? [] : @report.selected.map(&:key), everything: everything?,
      window_label: window.label, words: window.words, scope: scope,
      pages: @report.pages.map { |page| page_switch(page) }, numbers: METRICS.map { |metric| number_of(metric) },
      columns: METRICS.map { |metric| ProgressChart::Visits::LABELS.fetch(metric) },
      sources: sources, countries: countries, rows: rows, links: links, badges: badges
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

  # value: the first number charted, on that page, while it is in view.
  def page_switch(page)
    on = @report.selected.include?(page)
    { key: page.key, name: page.name, rank: page.rank, on: on, value: (number(@report.total(@report.metrics.first, page: page)) if on) }
  end

  def number_of(metric)
    on = @report.metrics.include?(metric)
    { key: metric, label: ProgressChart::Visits::LABELS.fetch(metric), group: ProgressChart::Visits::GROUPS.fetch(metric),
      value: number(@report.total(metric)), change: change(@report.change(metric)), on: on,
      chart: (ChartSerializer.new(ProgressChart::Visits.new(@report, metric)).attributes if on) }
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

  # The pages picked, busiest in the first number charted first, each number
  # with its change against the days before.
  def rows
    @report.selected.sort_by { |page| -@report.total(@report.metrics.first, page: page) }.map do |page|
      cells = METRICS.map do |metric|
        value = @report.total(metric, page: page)
        { value: value.positive? ? number(value) : "–", change: change(@report.change(metric, page: page)) }
      end
      { key: page.key, name: page.name, rank: page.rank, cells: cells }
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
