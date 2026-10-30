# The Pro analytics page for one window, the numbers drawn and the pages in
# view: the chart filter every chart page shows (ChartFilterSerializer), its
# toggles and its table's cells each with its change against the window
# before, and under it both sets of panels, so the switch between them
# fetches nothing: where visitors to the builder's pages on Openstage came
# from, the links they followed and where the badge and embed showed; and
# the panels of their websites. The page renders it first and its script
# asks for others (Api::AnalyticsController).
class AnalyticsViewSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include Rails.application.routes.url_helpers

  # report: an Analytics::ReportService.
  def initialize(report)
    @report = report
  end

  # changes_note: what the changes compare with, while a toggle or a cell
  # has one (never for all time, which compares with nothing); quiet: what a
  # panel with nothing in it says ("in the last 30 days", "between 3 Oct and
  # 28 Oct", "yet").
  def attributes
    @attributes ||= begin
      view = ChartFilterSerializer.new(@report, changes: true, table: ProjectsTableSerializer.new(@report, changes: true)).attributes
      view.merge(changes_note: (changes_note if compared?(view)), quiet: quiet, sources: bars(@report.sources), countries: counts(@report.countries),
                 links: links, badges: badges, websites: websites)
    end
  end

  private

  def labels
    @report.totals_window.labels
  end

  def compared?(view)
    view[:numbers].any? { |number| number[:change] } || view[:table][:rows].any? { |row| row[:cells].any? { |cell| cell[:change] } }
  end

  def changes_note
    before = labels.before
    "Changes compare each value with #{before}." if before
  end

  def quiet
    labels.range == "all" ? "yet" : labels.word
  end

  # Each with a bar as wide as its share of the busiest.
  def bars(pairs)
    most = pairs.map(&:last).max.to_i
    pairs.map { |label, count| { label: label, count: number_with_delimiter(count), width: (100.0 * count / most).round } }
  end

  def counts(pairs)
    pairs.map { |label, count| { label: label, count: number_with_delimiter(count) } }
  end

  def links
    @report.links.map { |link| { title: link.title, page: link.page.name, count: number_with_delimiter(link.count) } }
  end

  def badges
    @report.badges.map { |kind, count, sites| { label: kind == "badge" ? "README badge" : "Embed widget", count: number_with_delimiter(count), sites: pluralize(sites, "site") } }
  end

  # The panels of the builder's websites (Analytics::GatherWebsitesService),
  # sources with bars as Openstage's own; with none of them, what shows
  # instead (empty) and, while none of the projects in view counts site
  # visits, the first one's Site visits row, which sets them up (setup).
  def websites
    site = @report.websites
    ranks = site.ranks
    { sources: bars(ranks["source"]), refs: counts(ranks["ref"]), countries: counts(ranks["country"]), pages: pages(ranks["page"]),
      empty: empty_words(site.state), setup: (setup if site.state == :off) }
  end

  # Each with its project while pages of several projects count
  # (SiteVisits::RankService), nil otherwise and for Other.
  def pages(rows)
    rows.map { |label, count, project| { label: label, count: number_with_delimiter(count), project: project } }
  end

  def empty_words(state)
    case state
    when :quiet then "No site visits #{quiet}."
    when :off then "None of the projects in view counts site visits."
    end
  end

  def setup
    row = @report.setup_row
    { text: "Set up #{row.name}'s site visits", path: edit_project_path(row.repo, site: "open", anchor: "site-visits") } if row
  end
end
