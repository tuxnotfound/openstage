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
  // Every number the view has; the charted ones (on) with their chart.
  numbers: NumberView[]
  shipped: { heading: string; empty: string; items: ShippedItem[] }
  // The dashboard's table of projects under its chart.
  table: ProjectsTable | null
}

export type NumberView = {
  key: string
  label: string
  value: string
  change: { arrow: string | null; words: string | null; up: boolean | null }
  on: boolean
  chart: ChartView | null
}

export type ProjectsTable = { columns: { key: string; label: string }[]; rows: ProjectsRow[] }

// chart: whether the dashboard's chart draws it, null for a project hidden
// from the page; values: by column key, null for a number it does not have;
// setup: where to start counting its site visits.
export type ProjectsRow = {
  repo: string
  name: string
  rank: Rank
  edit: string | null
  page: { on: boolean; path: string } | null
  chart: boolean | null
  values: Record<string, string | null>
  setup: string | null
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
  selected: string[]
  everything: boolean
  windowLabel: string
  words: string
  scope: string
  // value: the first number charted, on that page, while it is in view.
  pages: { key: string; name: string; rank: Rank; on: boolean; value: string | null }[]
  // group: where the number happens: "On GitHub", "On your websites" or
  // "On Openstage"; chart: the charted ones' (on).
  numbers: { key: Metric; label: string; group: string; value: string; change: AnalyticsChange; on: boolean; chart: ChartView | null }[]
  // The table's columns, a number each, in the numbers' order.
  columns: string[]
  sources: { label: string; count: string; width: number }[]
  countries: { label: string; count: string }[]
  rows: { key: string; name: string; rank: Rank; cells: { value: string; change: AnalyticsChange }[] }[]
  links: { title: string; page: string; count: string }[]
  badges: { label: string; count: string; sites: string }[]
}
