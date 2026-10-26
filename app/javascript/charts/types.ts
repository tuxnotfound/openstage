// The views the API sends (app/serializers), camelCased: the pages render
// them as they arrive, and compute nothing of their own.

export type Rank = number | null

export type ChartView = {
  // dashed: site visits, drawn dotted beside solid commits.
  paths: { d: string; rank: Rank; dashed: boolean }[]
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
}

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
