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
  // value: null on a chart that compares numbers, each on its own peak.
  ticks: { value: string | null; top: number }[]
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
  // The colour its box wears; null for a row with no box.
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
// list under the cards, null with none.
export type TableView = {
  columns: { key: string; label: string; word: string; beside: string | null }[]
  rows: TableRow[]
  stack: "md" | "lg"
  more: { text: string; anchor: string } | null
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

// The analytics page (AnalyticsViewSerializer): the chart filter, then both
// sets of panels: where views of the builder's pages on Openstage came
// from, the links followed and the badge and embed; and the panels of
// their websites.
export type AnalyticsView = FilterView & {
  // What the changes compare with; null for all time.
  changesNote: string | null
  // What a panel with nothing in it says: "in the last 30 days", "yet".
  quiet: string
  sources: { label: string; count: string; width: number }[]
  countries: { label: string; count: string }[]
  links: { title: string; page: string; count: string }[]
  badges: { label: string; count: string; sites: string }[]
  websites: WebsitesView
}

// The panels of the builder's websites, each value with its count, the
// busiest first and Other last, what the list leaves out, a page with its
// project while pages of several projects count; with none of them, what shows
// instead (empty) and, while none of the projects in view counts site
// visits, the link that sets up the first one's (setup).
export type WebsitesView = {
  sources: { label: string; count: string; width: number }[]
  refs: { label: string; count: string }[]
  countries: { label: string; count: string }[]
  pages: { label: string; count: string; project: string | null }[]
  empty: string | null
  setup: { text: string; path: string } | null
}
