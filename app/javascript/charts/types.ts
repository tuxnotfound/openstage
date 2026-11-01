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
  // key: the row's (TableRow); number: the number's.
  paths: { d: string; colorClass: string; number: string; key: string }[]
  ticks: { value: string; top: number }[]
  // values: one per tip, "–" where the project shows none of it.
  columns: { left: number; width: number; mark: number; title: string; rows: { key: string; name: string; colorClass: string; values: string[] }[] }[]
  // The numbers with lines, in the pages' order: the note names their styles.
  heads: string[]
  // The tooltip's columns: each number with lines, then any the server
  // shows beside it, which has no line of its own (line false).
  tips: { key: string; label: string; line: boolean }[]
  axis: string[]
  ariaLabel: string
  // As the server's first paint writes it; when the chart compares numbers,
  // the browser names the line styles between noteParts' before and after.
  note: string
  noteParts: { before: string; after: string } | null
  none: string
  indexed: boolean
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
  // lists it (GithubReposController's path to switch it), and
  // Projects::NumbersController's path for its switches.
  edit: string | null
  page: { on: boolean; path: string } | null
  switch: string | null
}

// columns: a number each, with its names, whether a project here shows it or
// not, and the number it sits beside (beside), null for one with lines of
// its own. stack: the breakpoint below which the table stacks, as on a
// phone, where its columns no longer fit (ProjectsTableSerializer#stack).
export type TableView = { columns: { key: string; label: string; word: string; beside: string | null }[]; rows: TableRow[]; stack: "md" | "lg" }

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

// A builder's page, a project's page or the dashboard (ProgressViewSerializer).
export type ProgressView = FilterView & {
  shipped: { heading: string; empty: string; items: ShippedItem[] } | null
}

export type ShippedItem = {
  id: number
  // null for the entry a link pointed at, which shows above the page instead.
  anchor: string | null
  date: string
  kind: string
  title: string
  runIn: string
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
