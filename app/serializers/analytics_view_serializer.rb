# A tab of the analytics page for one window, the numbers drawn and the
# pages in view (Analytics::ReportService): the chart filter every chart
# page shows (ChartFilterSerializer), its table's cells each with its change
# against the window before, its rows the ones with a colour, ten projects
# at most, with how many it leaves out (ProjectsTableSerializer), and none
# on a tab with no row, whose chart says why; the page's tabs
# (AnalyticsTabsSerializer); a tile per number, a toggle for one with lines
# and a figure for one that sits beside another; and the tab's own parts,
# never another tab's: the Commits tab's (AnalyticsCommitsSerializer), its
# Active days among the tiles and Last commit in the table, and the lists
# (AnalyticsListsSerializer). The page renders it first
# and its script asks for others (Api::AnalyticsController).
class AnalyticsViewSerializer < ApplicationSerializer
  # report: an Analytics::ReportService.
  def initialize(report)
    @report = report
  end

  # rows_label: what a row is, "Pages" or "Projects"; changes_note: what the
  # changes compare with, while a tile or a cell has one (never for all
  # time, which compares with nothing); quiet: what a list with nothing in
  # it says after its words ("in the last 30 days", "between 3 Oct and 28
  # Oct", "yet"). revenue: the MRR tab's lists, to come.
  def attributes
    @attributes ||= begin
      commits = AnalyticsCommitsSerializer.new(@report) if @report.commit_parts
      table = ProjectsTableSerializer.new(@report, changes: true, boxed_only: true, anchor: nil, text: commits&.last_commits)
      filter = ChartFilterSerializer.new(@report, changes: true, table: table)
      view = filter.attributes
      view[:table] = nil if view[:table][:rows].empty?
      tiles = @report.tiles.map { |total| filter.number_of(total).merge(figure: !total.number.drawable?, suffix: nil) } + [ commits&.tile ].compact
      lists = AnalyticsListsSerializer.new(@report, quiet: quiet)
      view.merge(locked: false, tab: @report.tab.key, **AnalyticsTabsSerializer.new(@report.user).attributes, tiles: tiles,
                 rows_label: @report.per == "page" ? "Pages" : "Projects", changes_note: (changes_note if compared?(view, tiles)), quiet: quiet,
                 site: lists.site, pages: lists.pages, commits: commits&.attributes, revenue: nil)
    end
  end

  private

  def labels
    @report.totals_window.labels
  end

  def compared?(view, tiles)
    tiles.any? { |tile| tile[:change] } || Array(view.dig(:table, :rows)).any? { |row| row[:cells].any? { |cell| cell[:change] } }
  end

  def changes_note
    before = labels.before
    "Changes compare each value with #{before}." if before
  end

  def quiet
    @quiet ||= labels.range == "all" ? "yet" : labels.word
  end
end
