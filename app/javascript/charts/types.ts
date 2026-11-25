// The views the API sends (app/serializers), camelCased: every number in
// them is the server's, and so is every colour (a class that sets
// --project, ProgressChart::Palette): the pages only arrange them
// (filter/lines.ts).

// One of the four windows, or days picked: "2026-10-03..2026-10-28".
export type ProgressRange = "30d" | "90d" | "12m" | "all" | `${string}..${string}`

// What the window's calendar offers (ChartFilterSerializer): today in the
// builder's zone, the first day anything here counted (null with none), and
// the days picked on screen with their name for the pill, null for the
// other windows.
export type CalendarView = { today: string; earliest: string | null; picked: { from: string; to: string; name: string } | null }

// A chart filter's chart (CompareChartSerializer): each line carries its
// project, its colour and its number, and the browser gives it its number's
// line style.
export type CompareChartView = {
  // key: the row's (TableRow); number: the number's; start: the point its
  // first vertex stands on.
  paths: { d: string; colorClass: string; number: string; key: string; start: number }[]
  // value: the gridline's on a chart of one number, else null; values:
  // each number's on a chart that compares them, each on its own axis.
  ticks: { value: string | null; top: number; values: { key: string; label: string }[] }[]
  // values: one per tip, "–" where the project shows none of it.
  columns: { left: number; width: number; mark: number; title: string; rows: { key: string; name: string; colorClass: string; values: string[] }[] }[]
  // The tooltip's columns: each number with lines, then any the server
  // shows beside it, which has no line of its own (line false).
  tips: { key: string; label: string; line: boolean }[]
  axis: string[]
  marks: ChartMark[]
  ariaLabel: string
  // Why a number drawn has no line; null when every one has.
  note: string | null
  none: string
  indexed: boolean
}

// What an entry is, by the mark it wears (TallyService::Item#badge): a
// milestone's flag, the rocket of anything else shipped, the bubble of what
// was published.
export type Badge = "milestone" | "shipped" | "published"

// The shipped and published entries at one point of one project
// (ProgressChart::Marks): key, its project's row, null for none; number, the
// line it sits on, null on the axis; left and top, where, in percent of the
// chart from its top left; badge, the first of milestone, shipped and
// published among its entries; label, its newest for a screen reader;
// entries, newest first, each with its badge in words (kind), its row's
// anchor id being entry-<id>.
export type ChartMark = {
  key: string | null
  number: string | null
  colorClass: string
  column: number
  left: number
  top: number
  badge: Badge
  label: string
  entries: { id: number; title: string; badge: Badge; kind: string; date: string }[]
}

// A change against the window before, as the pages write it: the arrow
// carries the direction and only it wears the colour; nulls with nothing
// to compare with.
export type Change = { arrow: string | null; text: string | null; up: boolean | null }

// A number the page's rows show: its total for the rows in view, each one's
// part of it for the toggle's bar, in its colour, and its change on the
// dashboard and analytics.
export type NumberView = {
  key: string
  label: string
  // Its name inside a sentence: "site visits", "MRR".
  word: string
  // Where it happens, for the toggles grouped under it: "On GitHub".
  group: string
  value: string
  // colorClass: null for a row with no colour, whose share stays empty.
  // The rows past the palette share one part, keyed "others", with no colour.
  split: { key: string; colorClass: string | null; value: number }[]
  change: Change | null
}

// A cell of the table: the row's value over the window, or null; shown:
// whether visitors see it; pick: the dashboard's switch for what visitors
// see, null without one; link: what stands in its place where site visits
// do not count, to the project's Site visits row (CellLink); change: its
// change on analytics, null elsewhere.
export type TableCell = { key: string; value: string | null; shown: boolean; pick: boolean | null; link: CellLink | null; change: Change | null }

// Set up where the project counts no site visits (the script off, or waiting
// for its first visit), Paused where Free counts another project's: its
// words on screen (text) and for a screen reader (label), and the project's
// Site visits row it leads to (path).
export type CellLink = { text: string; label: string; path: string }

export type TableRow = {
  // Its repo's full name, or on analytics "page" for the builder's own
  // page, which draws in ink.
  key: string
  name: string
  // Its words under the table's text column, null with none.
  text?: string | null
  // The colour its box wears, or on analytics its swatch where it has no
  // box; null for a project past the palette.
  colorClass: string | null
  // In view on the chart; drawable: on the builder's page, so it has a box.
  on: boolean
  drawable: boolean
  cells: TableCell[]
  // The dashboard's: the project's own view, whether the builder's page
  // lists it (GithubReposController's path to switch it), whether it is
  // pinned there, which is whether it has a colour (Projects::PinsController's
  // path; null while the page does not list it), and
  // Projects::NumbersController's path for its switches.
  edit: string | null
  page: { on: boolean; path: string } | null
  pin: { on: boolean; path: string; title: string } | null
  switch: string | null
}

// columns: a number each, with its names, whether a project here shows it or
// not, and the number it sits beside (beside), null for one with lines of
// its own. stack: the breakpoint below which the table stacks, as on a
// phone, where its columns no longer fit (ProjectsTableSerializer#stack).
// more: on a builder's stage, the link to the projects it leaves to the
// list under the cards; on analytics, how many it leaves out, with no
// anchor; null with none.
export type TableView = {
  columns: { key: string; label: string; word: string; beside: string | null }[]
  rows: TableRow[]
  stack: "md" | "lg"
  more: { text: string; anchor: string | null } | null
  // A column of words after the numbers, analytics' Last commit, each row's
  // in its text; none elsewhere.
  text?: { label: string }
}

// The stage's list of the projects past the cards, a page of them
// (ProjectListSerializer): commits, countWords (what a screen reader hears
// after the count) and line (its weekly commits over 52 weeks, an SVG path
// in a box 400 by 56) null while visitors do not see its commits or it has
// none then; last null while they do not see them. On the dashboard, edit,
// page and pin as a TableRow has them; null on the stage.
export type ProjectListRow = {
  key: string
  name: string
  path: string
  description: string | null
  live: boolean
  archived: boolean
  commits: number | null
  countWords: string | null
  line: string | null
  last: string | null
  edit: string | null
  page: { on: boolean; path: string } | null
  pin: { on: boolean; path: string; title: string } | null
}

// liveLabel: null while none is live, and the list offers no filter; range:
// null with no project found, and empty says why. hidden: whether it lists
// the projects hidden from the stage instead; hiddenLabel: null unless the
// dashboard lists others beside them. back: on the dashboard,
// what each row's switch sends beside its own, [name, value] pairs, so the
// dashboard comes back on this view; null on the stage.
export type ProjectListView = {
  title: string
  sort: string
  query: string
  live: boolean
  hidden: boolean
  page: number
  pages: number
  sorts: { key: string; label: string }[]
  liveLabel: string | null
  hiddenLabel: string | null
  range: string | null
  empty: string | null
  rows: ProjectListRow[]
  back: [string, string][] | null
}

// A chart filter's view, the same on every chart page (ChartFilterSerializer).
export type FilterView = {
  range: ProgressRange
  // What a number's total covers: "last 90 days", "all time", "3 Oct – 28 Oct".
  words: string
  calendar: CalendarView
  // The rows in view; none for all of them.
  selected: string[]
  numbers: NumberView[]
  // The numbers drawn, in line order; defaultShow: the page's own.
  drawn: string[]
  defaultShow: string[]
  chart: CompareChartView
  table: TableView | null
}

// A builder's page, a project's page or the dashboard (ProgressViewSerializer);
// shipped's heading is null while the window holds none.
export type ProgressView = FilterView & {
  shipped: { heading: string | null; empty: string; items: ShippedItem[] } | null
}

// A row of What's new: its badge, in words (kind) and in its project's
// colour (colorClass), and its description (body), null without one;
// project, null on a project's own page.
export type ShippedItem = {
  id: number
  // null for the entry a link pointed at, which shows above the page instead.
  anchor: string | null
  date: string
  badge: Badge
  kind: string
  colorClass: string
  title: string
  runIn: string
  body: string | null
  url: string | null
  project: string | null
}

// The analytics page's tabs (Analytics::Tab), each a link to its own
// address (path), to which the page adds the window and the projects in
// view; pro: this builder's plan does not open it, so it wears Pro's mark.
export type Tab = "overview" | "commits" | "visits" | "mrr" | "openstage"
export type TabLink = { key: Tab; label: string; pro: boolean; path: string }

// A number above an analytics tab's chart: a toggle while it has lines of
// its own; a figure (figure) while it sits beside another, which draws
// none, so it is no button; suffix: what follows its value, "of 30".
export type Tile = NumberView & { figure: boolean; suffix: string | null }

// A row of a ranked list (AnalyticsListsSerializer): width, its bar, its
// share of the first row in percent; colorClass and of, the dot and the
// name of its project or page, null with none; other, the row of what the
// list leaves out, which has no bar.
export type RankedRow = { label: string; count: string; width: number; colorClass: string | null; of: string | null; other: boolean }
// empty: what the list says with no row, null with any.
export type Ranked = { rows: RankedRow[]; empty: string | null }

// The lists of the builder's websites, on Site visits: with none of them,
// what shows instead (empty) and, while none of the projects in view
// counts site visits, the link that sets one up (setup).
export type SiteLists = {
  pages: Ranked
  sources: Ranked
  refs: Ranked
  countries: Ranked
  empty: string | null
  setup: { text: string; path: string } | null
}

// The lists of the builder's pages on Openstage, on Openstage views, and
// where the badge and the embed were shown.
export type PageLists = {
  sources: Ranked
  countries: Ranked
  links: Ranked
  badges: { label: string; count: string; sites: string }[]
}

// A tab of the analytics page (AnalyticsViewSerializer): the chart filter,
// its tiles, and its own lists, null on every other tab.
export type AnalyticsView = FilterView & {
  locked: false
  tab: Tab
  tabs: TabLink[]
  tiles: Tile[]
  // What a row is: "Pages" while the builder's stage is one, else "Projects".
  rowsLabel: string
  // What the changes compare with; null for all time.
  changesNote: string | null
  // What a list with nothing in it says after its words: "in the last 30 days", "yet".
  quiet: string
  site: SiteLists | null
  pages: PageLists | null
  commits: CommitParts | null
  revenue: RevenueParts | null
}

// The MRR tab's parts under its chart (AnalyticsRevenueSerializer): its
// products, each a ranked row with its subscriptions; and MRR by week or
// by month, newest first, each row with what it added or took (amount, "–"
// for nothing, up saying which) and where MRR stood at its end; with no
// product counted for a project, the line that says so (empty).
export type RevenueParts = {
  products: (RankedRow & { subscriptions: string })[]
  steps: { title: string; rows: { label: string; amount: string; up: boolean | null; mrr: string }[] }
  empty: string | null
}

// The Commits tab's parts under its chart (AnalyticsCommitsSerializer):
// when the builder commits, a row per weekday, Monday first, and a cell
// per hour, its step 0 for none, then 1 to 4 by quarters of the busiest
// cell, and its words (title); and what's new, newest first, or the line
// that says there is nothing (newsEmpty).
export type CommitParts = {
  hours: { name: string; cells: { step: 0 | 1 | 2 | 3 | 4; title: string }[] }[]
  news: NewsItem[]
  newsEmpty: string
}

// An entry of the Commits tab's What's new: its mark, in words (kind) and
// in its project's colour, its title, its project and its day.
export type NewsItem = { id: number; date: string; badge: Badge; kind: string; colorClass: string; title: string; project: string | null }

// A tab Free does not open (AnalyticsLockedSerializer): what it shows on
// Pro, and the button to Pro; nothing of its numbers.
export type LockedView = {
  locked: true
  tab: Tab
  tabs: TabLink[]
  pitch: string
  checkout: { label: string; path: string }
}

// Where the project picked on Set up site visits stands
// (SiteVisitsStatusSerializer): its step, the app's line for its first
// visit once one came, and whether its page shows its site visits.
export type SiteStatusView = { step: "pick" | "line" | "done"; firstVisit: string | null; seen: boolean }

// Set up site visits (SiteVisitsSetupSerializer): the projects to pick
// from, the one picked with its website, its line and where it leads,
// where it stands, and what a refused Continue said. project and status
// are null for a builder with no project yet.
export type SiteSetupView = {
  projects: { id: number; label: string }[]
  free: boolean
  refusal: string | null
  project: {
    id: number; name: string; host: string | null; website: string; visit: string | null; line: string | null; note: string | null
    page: string; dashboard: string; numbers: string; statusPath: string
  } | null
  status: SiteStatusView | null
  paths: { setup: string; pricing: string; privacy: string; connect: string }
}

// The dashboard's list of projects (DashboardProjectsSerializer): a row per
// project with its colour while it wears one and its switch, On your stage;
// past ten projects, the views and their counts, the page, and the app's
// words for a search that finds nothing.
export type DashboardRow = { id: number; name: string; colorClass: string | null; pinned: boolean; stage: boolean; switch: string }
export type DashboardView = "pinned" | "all" | "hidden"
export type DashboardList = {
  many: boolean; count: number; view: DashboardView; query: string; page: number; pages: number; pinned: number
  views: { key: DashboardView; label: string; count: string }[]; range: string | null; empty: string | null; connect: string | null; rows: DashboardRow[]
}

// A project's numbers on the dashboard (DashboardLinesSerializer), a line
// each with where it comes from and its one control: a switch for what
// visitors see, a step that sets the number up (filled for the first), or
// Pro's mark.
export type DashboardControl =
  | { kind: "switch"; on: boolean; dead: boolean; path: string; number: string | null; aria: string; filled: boolean }
  | { kind: "link"; label: string; path: string; aria: string; filled: boolean }
  | { kind: "pro"; filled: boolean }
export type DashboardLine = { key: string; name: string; state: string; sep: boolean; control: DashboardControl }
export type DashboardLines = { id: number; name: string; colorClass: string | null; page: string; edit: string; lines: DashboardLine[] }

// A sync of the builder's work, newest first, at the foot of the list.
export type SyncLogView = { state: "up" | "down" | "warn"; source: string; added: number | null; ago: string }
