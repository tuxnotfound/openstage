// The views the API sends (app/serializers), camelCased: the pages render
// them as they arrive, and compute nothing of their own.

export type Rank = number | null

export type ChartView = {
  paths: { d: string; rank: Rank }[]
  ticks: { value: number; top: number }[]
  columns: { left: number; width: number; mark: number; title: string; rows: { name: string; rank: Rank; value: string }[] }[]
  axis: string[]
  ariaLabel: string
  note: string
  emptyNote: string
  none: string
  empty: boolean
  average: boolean
  // Each line's project, in drawing order's reverse: the busiest first.
  legend: { name: string; rank: Rank }[]
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
  // A project's page with site visits: the same window's, for its tab.
  site: SiteView | null
}

export type SiteView = {
  value: string
  visitors: string
  chart: ChartView
}

// The number a project's page charts.
export type ProjectMetric = "commits" | "visits"

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
export type Metric = "visitors" | "views" | "follows" | "clicks"
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
  tabs: { metric: Metric; label: string; value: string; change: AnalyticsChange }[]
  label: string
  scope: string
  total: string
  change: AnalyticsChange
  chart: ChartView
  sources: { label: string; count: string; width: number }[]
  countries: { label: string; count: string }[]
  rows: { key: string; name: string; rank: Rank; values: string[]; change: AnalyticsChange }[]
  links: { title: string; page: string; count: string }[]
  badges: { label: string; count: string; sites: string }[]
}
