// The views the API sends (app/serializers), camelCased: the pages render
// them as they arrive, and compute nothing of their own.

export type Rank = number | null

export type ChartView = {
  // dashed: site visits, drawn dotted beside solid commits; key: the line a
  // dashboard switch hides ("repo|number"), null on the other charts.
  paths: { d: string; rank: Rank; dashed: boolean; key: string | null }[]
  // value: a count, or a share of each line's peak ("50%") when the chart compares numbers.
  ticks: { value: number | string; top: number }[]
  columns: { left: number; width: number; mark: number; title: string; rows: { name: string; rank: Rank; value: string }[] }[]
  axis: string[]
  ariaLabel: string
  note: string
  emptyNote: string
  none: string
  empty: boolean
  average: boolean
  // Each line's project, in drawing order's reverse: the busiest first.
  legend: { name: string; rank: Rank; dashed: boolean }[]
}

export type ProgressRange = "30d" | "90d" | "12m" | "all"

// A chart filter's chart (CompareChartSerializer): each line carries its
// project and its number, and the browser gives it its number's line style.
export type CompareChartView = {
  // repo: the project's repo; number: the number's key.
  paths: { d: string; rank: Rank; number: string; repo: string }[]
  ticks: { value: string; top: number }[]
  // values: one per number in heads, "–" where the project counts none.
  columns: { left: number; width: number; mark: number; title: string; rows: { repo: string; name: string; rank: Rank; values: string[] }[] }[]
  // The numbers with lines, in the pages' order: the tooltip's columns.
  heads: string[]
  axis: string[]
  ariaLabel: string
  // As the server's first paint writes it; when the chart compares numbers,
  // the browser names the line styles between noteParts' before and after.
  note: string
  noteParts: { before: string; after: string } | null
  none: string
  empty: boolean
  indexed: boolean
}

// A number the page's projects show: its total for the projects in view,
// each one's part of it for the toggle's bar, and its change on the dashboard.
export type NumberView = {
  key: string
  label: string
  // Its name inside a sentence: "site visits", "MRR".
  word: string
  value: string
  split: { repo: string; rank: Rank; value: number }[]
  change: AnalyticsChange | null
}

// A cell of the projects' table: the project's value over the window, or
// null; shown: whether visitors see it; pick: the dashboard's switch for
// what visitors see, null without one; setup: where to start counting.
export type TableCell = { key: string; value: string | null; shown: boolean; pick: boolean | null; setup: string | null }

export type TableRow = {
  repo: string
  name: string
  rank: Rank
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

// columns: a number each, with its names, whether a project here shows it or not.
export type TableView = { columns: { key: string; label: string; word: string }[]; rows: TableRow[] }

export type ProgressView = {
  range: ProgressRange
  // What a number's total covers: "last 90 days", "all time".
  words: string
  // The projects in view; none for all of them.
  selected: string[]
  numbers: NumberView[]
  // The numbers drawn, in line order; defaultShow: the page's own.
  drawn: string[]
  defaultShow: string[]
  chart: CompareChartView
  table: TableView | null
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

export type AnalyticsRange = "7d" | "30d" | "90d"
export type Metric = "commits" | "site" | "visitors" | "views" | "follows" | "clicks"
export type AnalyticsChange = { arrow: string | null; text: string | null; up: boolean | null }

export type AnalyticsView = {
  range: AnalyticsRange
  metric: Metric
  selected: string[]
  everything: boolean
  windowLabel: string
  words: string
  // value: the number charted, on that page, while it is in view.
  pages: { key: string; name: string; rank: Rank; on: boolean; value: string | null }[]
  // group: where the number happens: "On GitHub", "On your websites" or "On Openstage".
  tabs: { metric: Metric; label: string; group: string; value: string; change: AnalyticsChange }[]
  label: string
  scope: string
  // The table's last column: the picked number against the days before.
  changeLabel: string
  total: string
  change: AnalyticsChange
  chart: ChartView
  sources: { label: string; count: string; width: number }[]
  countries: { label: string; count: string }[]
  rows: { key: string; name: string; rank: Rank; values: string[]; change: AnalyticsChange }[]
  links: { title: string; page: string; count: string }[]
  badges: { label: string; count: string; sites: string }[]
}
