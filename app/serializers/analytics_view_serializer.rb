# The Pro analytics page for one window, the numbers drawn and the pages in
# view: the chart filter every chart page shows (ChartFilterSerializer), its
# toggles and its table's cells each with its change against the window
# before, and under it where visitors came from, the links they followed and
# where the badge and embed showed. The page renders it first and its script
# asks for others (Api::AnalyticsController).
class AnalyticsViewSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper

  # report: an Analytics::ReportService.
  def initialize(report)
    @report = report
  end

  # changes_note: what the changes compare with, while a toggle or a cell
  # has one (never for all time, which compares with nothing); quiet: what a
  # panel with nothing in it says ("in the last 30 days", "yet").
  def attributes
    @attributes ||= begin
      view = ChartFilterSerializer.new(@report, changes: true, table: ProjectsTableSerializer.new(@report, changes: true)).attributes
      view.merge(changes_note: (changes_note if compared?(view)), quiet: quiet, sources: sources, countries: countries, links: links, badges: badges)
    end
  end

  private

  def labels
    @report.period.labels
  end

  def compared?(view)
    view[:numbers].any? { |number| number[:change] } || view[:table][:rows].any? { |row| row[:cells].any? { |cell| cell[:change] } }
  end

  def changes_note
    span = Progress::WindowLabels::SPANS[labels.range]
    "Changes compare each value with the #{span} before." if span
  end

  def quiet
    labels.range == "all" ? "yet" : "in the #{labels.span_words}"
  end

  def sources
    most = @report.sources.first&.last.to_i
    @report.sources.map { |label, count| { label: label, count: number_with_delimiter(count), width: (100.0 * count / most).round } }
  end

  def countries
    @report.countries.map { |label, count| { label: label, count: number_with_delimiter(count) } }
  end

  def links
    @report.links.map { |link| { title: link.title, page: link.page.name, count: number_with_delimiter(link.count) } }
  end

  def badges
    @report.badges.map { |kind, count, sites| { label: kind == "badge" ? "README badge" : "Embed widget", count: number_with_delimiter(count), sites: pluralize(sites, "site") } }
  end
end
