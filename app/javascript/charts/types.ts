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

export type ProgressView = {
  range: ProgressRange
  selected: string[]
  filtered: boolean
  words: string
  scope: string
  commits: number
  change: { arrow: string | null; words: string | null; up: boolean | null }
  shares: { repo: string; name: string; rank: number; commits: number; percent: number }[]
  kpis: string
  // value: the project's commits in the window, while it is in view.
  projects: { repo: string; name: string; rank: number; on: boolean; value: string | null }[]
  chart: ChartView
  shipped: { heading: string; empty: string; items: ShippedItem[] }
  // The site visits the chart can draw beside the commits, for the same window.
  site: SiteView | null
  // The dashboard's chart, with the lines switched off left out, and its table.
  lines: LinesView | null
}

// A cell of the dashboard's table: the window's value and its switch; setup:
// where to start counting a number the project has none of.
export type LineCell = { value: string | null; on: boolean; setup: string | null }

export type LinesRow = {
  repo: string
  name: string
  rank: Rank
  // The project's own view; null without a synced repo behind it.
  edit: string | null
  // Whether the builder's page shows it, and GithubReposController's path to switch it.
  page: { on: boolean; path: string } | null
  // Projects::DashboardNumbersController's path for this project; null
  // without a synced repo behind it, so nothing to save.
  switch: string | null
  commits: LineCell
  visits: LineCell
}

export type LinesView = { chart: ChartView; rows: LinesRow[]; visits: string | null }

// chart: the visits alone; compare: commits and visits, each line against its own peak.
export type SiteView = {
  value: string
  visitors: string
  chart: ChartView
  compare: ChartView
}

// The numbers a chart can draw.
export type ChartNumber = "commits" | "visits"

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
export type Metric = "visitors" | "views" | "follows" | "clicks" | "site"
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
  // group: where the number happens, "Your websites" or "On Openstage".
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
