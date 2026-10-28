// The views the API sends (app/serializers), camelCased: the pages render
// them as they arrive, and compute nothing of their own.

export type Rank = number | null

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

// A change against the window before, as the pages write it: the arrow
// carries the direction and only it wears the colour; nulls with nothing
// to compare with.
export type Change = { arrow: string | null; text: string | null; up: boolean | null }

// A number the page's rows show: its total for the rows in view, each one's
// part of it for the toggle's bar, and its change on the dashboard and
// analytics.
export type NumberView = {
  key: string
  label: string
  // Its name inside a sentence: "site visits", "MRR".
  word: string
  // Where it happens, for the toggles grouped under it: "On GitHub".
  group: string
  value: string
  split: { repo: string; rank: Rank; value: number }[]
  change: Change | null
}

// A cell of the table: the row's value over the window, or null; shown:
// whether visitors see it; pick: the dashboard's switch for what visitors
// see, null without one; setup: where to start counting; change: its change
// on analytics, null elsewhere.
export type TableCell = { key: string; value: string | null; shown: boolean; pick: boolean | null; setup: string | null; change: Change | null }

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

// A chart filter's view, the same on every chart page (ChartFilterSerializer).
export type FilterView = {
  range: ProgressRange
  // What a number's total covers: "last 90 days", "all time".
  words: string
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

// The analytics page (AnalyticsViewSerializer): the chart filter, then where
// visitors came from, the links they followed and the badge and embed.
export type AnalyticsView = FilterView & {
  // What the changes compare with; null for all time.
  changesNote: string | null
  // What a panel with nothing in it says: "in the last 30 days", "yet".
  quiet: string
  sources: { label: string; count: string; width: number }[]
  countries: { label: string; count: string }[]
  links: { title: string; page: string; count: string }[]
  badges: { label: string; count: string; sites: string }[]
}
