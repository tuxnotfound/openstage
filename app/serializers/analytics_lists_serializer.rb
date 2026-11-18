# The lists under an analytics tab's chart (Analytics::ReportService), each
# ranked: a row per value with its count and a bar as long as its share of
# the first, never under 1.5% so the smallest still shows, where a row
# carries one the dot and name of its project or page, then Other, what the
# list leaves out, with no bar; with no row, the line it says (empty). On
# Site visits, the builder's websites' (site); on Openstage views, their
# pages' on Openstage (pages); nil on every other tab.
class AnalyticsListsSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper
  include Rails.application.routes.url_helpers

  # quiet: what a list with nothing in it says after its words.
  def initialize(report, quiet:)
    @report = report
    @quiet = quiet
  end

  def attributes
    { site: site, pages: pages }
  end

  # Pages by page views, each with its project's dot while pages of several
  # count (SiteVisits::RankService); sources, ref tags and countries by
  # visitors. With none of them, what shows instead (empty) and, while none
  # of the projects in view counts site visits, the link that sets one up
  # (setup).
  def site
    site = @report.websites
    return unless site

    ranks = site.ranks
    { pages: ranked(ranks["page"], "No page views") { |path, count, project| [ readable(path), count, *page_of(project) ] },
      sources: ranked(ranks["source"], "No sources"), refs: ranked(ranks["ref"], "No ref tags"),
      countries: ranked(ranks["country"], "No countries") { |code, count| [ Country.name_of(code), count ] },
      empty: empty_words(site.state), setup: (setup if site.state == :off) }
  end

  # Sources and countries by views; the links followed, each with its
  # page's dot; and where the badge and the embed were shown.
  def pages
    return unless @report.on_pages

    { sources: ranked(@report.sources, "No views"),
      countries: ranked(@report.countries, "No countries") { |code, count| [ Country.name_of(code), count ] },
      links: ranked(@report.links, "No clicks out") { |link| [ link.title, link.count, link.page.color_class, link.page.name ] },
      badges: badges }
  end

  private

  # The block reads [label, count, color_class, of] from each of a
  # Ranked's rows; [label, count] are its own without one.
  def ranked(list, nothing)
    rows = list.rows.map { |row| block_given? ? yield(row) : row.first(2) }
    most = rows.map { |row| row[1] }.max.to_i
    shown = rows.map { |label, count, color_class, of| { label: label, count: number_with_delimiter(count), width: width(count, most), color_class: color_class, of: of, other: false } }
    shown << { label: Analytics::ReportService::OTHER, count: number_with_delimiter(list.other), width: 0, color_class: nil, of: nil, other: true } if list.other.positive?
    { rows: shown, empty: ("#{nothing} #{@quiet}." if shown.empty?) }
  end

  def width(count, most)
    most.positive? ? [ 1.5, 100.0 * count / most ].max.round(1) : 0
  end

  # Its project's colour and name, as the table names it, or its full name
  # when it has no row there, so two projects never share a name; nil
  # while pages of one project count.
  def page_of(project)
    return [ nil, nil ] unless project

    row = @report.rows.find { |each| each.key == project }
    row ? [ row.color_class, row.name ] : [ nil, project ]
  end

  # A path as its visitors read it: stored with the browser's escapes
  # ("/blog/s%C3%A3o-paulo"), cut at 200 characters, maybe through one. Left
  # without invisible characters, which a forged path could use to make the
  # list read wrong.
  def readable(path)
    URI.decode_uri_component(path.sub(/%\h?\z/, "")).scrub("").gsub(/[\p{Cc}\p{Cf}]/, "")
  end

  def empty_words(state)
    case state
    when :quiet then "No site visits #{@quiet}."
    when :off then "None of the projects in view counts site visits."
    end
  end

  def setup
    row = @report.setup_row
    { text: "Set up #{row.name}'s site visits", path: edit_project_path(row.repo, site: "open", anchor: "site-visits") } if row
  end

  def badges
    @report.badges.map { |kind, count, sites| { label: kind == "badge" ? "README badge" : "Embed widget", count: number_with_delimiter(count), sites: pluralize(sites, "site") } }
  end
end
