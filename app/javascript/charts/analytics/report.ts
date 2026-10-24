import * as d from "../dates"
import type { Day } from "../dates"
import type { ChartLine } from "../LineChart"

// What Analytics::ReportService reads for a window and the pages picked,
// summed here from the daily rows the server sends with the page.

export type Metric = "visitors" | "views" | "follows" | "clicks"
export const METRICS: Metric[] = ["visitors", "views", "follows", "clicks"]
export const METRIC_LABELS: Record<Metric, string> = { visitors: "Visitors", views: "Page views", follows: "New followers", clicks: "Clicks out" }

export type Range = "7d" | "30d" | "90d"
export const RANGES: Range[] = ["7d", "30d", "90d"]
export const DEFAULT_RANGE: Range = "30d"
const LENGTHS: Record<Range, number> = { "7d": 7, "30d": 30, "90d": 91 }

// key: "page" for the builder's own, else the repo's full name.
export type Page = { key: string; name: string; rank: number | null }

// [page, day, label, count]
export type Row = [string, Day, string, number]
// [link key, title, page, day, count]
export type LinkRow = [string, string, string, Day, number]
// [kind, day, referrer, count]
export type BadgeRow = [string, Day, string | null, number]

export type AnalyticsData = {
  today: Day
  range: Range
  metric: Metric
  selected: string[]
  pages: Page[]
  counts: Record<Metric, Record<string, Record<Day, number>>>
  sources: Row[]
  countries: Row[]
  links: LinkRow[]
  badges: BadgeRow[]
}

export type Bucket = { first: Day; last: Day }

const TOP = 6

export class Report {
  readonly days: [Day, Day]
  readonly previousDays: [Day, Day]
  readonly buckets: Bucket[]
  readonly selected: Page[]

  constructor(readonly data: AnalyticsData, readonly range: Range, readonly metric: Metric, picked: string[]) {
    const length = LENGTHS[range]
    const first = d.addDays(data.today, -(length - 1))
    this.days = [first, data.today]
    this.previousDays = [d.addDays(first, -length), d.addDays(first, -1)]
    const step = range === "90d" ? 7 : 1
    this.buckets = []
    for (let day = first; day <= data.today; day = d.addDays(day, step)) this.buckets.push({ first: day, last: d.min(d.addDays(day, step - 1), data.today) })
    const chosen = data.pages.filter((page) => picked.includes(page.key))
    this.selected = chosen.length > 0 ? chosen : data.pages
  }

  get everything(): boolean {
    return this.selected.length === this.data.pages.length
  }

  get label(): string {
    return this.range === "90d" ? "90 days" : `${LENGTHS[this.range]} days`
  }

  get words(): string {
    return `last ${this.label}`
  }

  get unit(): string {
    return this.range === "90d" ? "week" : "day"
  }

  total(metric: Metric, pages: Page[] = this.selected, [from, to]: [Day, Day] = this.days): number {
    const counts = this.data.counts[metric]
    return pages.reduce((sum, page) => sum + d.each(from, to).reduce((daySum, day) => daySum + (counts[page.key]?.[day] ?? 0), 0), 0)
  }

  // Percent against the days before; null when there were none.
  change(metric: Metric, pages: Page[] = this.selected): number | null {
    const before = this.total(metric, pages, this.previousDays)
    if (before === 0) return null
    const change = (100 * this.total(metric, pages)) / before - 100
    return Math.sign(change) * Math.round(Math.abs(change))
  }

  series(page: Page): number[] {
    const counts = this.data.counts[this.metric][page.key] ?? {}
    return this.buckets.map((bucket) => d.each(bucket.first, bucket.last).reduce((sum, day) => sum + (counts[day] ?? 0), 0))
  }

  // The pages picked with anything in the window, busiest first.
  get lines(): ChartLine[] {
    return this.selected
      .map((page) => ({ key: page.key, name: page.name, rank: page.rank, values: this.series(page) }))
      .filter((line) => line.values.some((value) => value > 0))
      .sort((a, b) => sum(b.values) - sum(a.values))
  }

  get sources(): [string, number][] {
    return this.top(this.data.sources).slice(0, TOP)
  }

  get countries(): [string, number][] {
    return this.top(this.data.countries).slice(0, 5)
  }

  // Entry links and project buttons, busiest first.
  get links(): { title: string; page: Page; count: number }[] {
    const totals = new Map<string, { title: string; page: Page; count: number }>()
    for (const [key, title, pageKey, day, count] of this.data.links) {
      const page = this.selected.find((each) => each.key === pageKey)
      if (!page || !this.inWindow(day)) continue
      const link = totals.get(key) ?? { title, page, count: 0 }
      link.count += count
      totals.set(key, link)
    }
    return [...totals.values()].sort((a, b) => b.count - a.count || compare(a.title, b.title)).slice(0, TOP)
  }

  // [kind, times shown, sites] for the README badge and the embed.
  get badges(): [string, number, number][] {
    return ["badge", "embed"].map((kind) => {
      const rows = this.data.badges.filter(([each, day]) => each === kind && this.inWindow(day))
      const sites = new Set(rows.map(([, , referrer]) => referrer).filter((referrer) => referrer))
      return [kind, rows.reduce((total, [, , , count]) => total + count, 0), sites.size]
    })
  }

  // One count per point, for the chart's tooltips.
  titles(): string[] {
    return this.buckets.map((bucket) => {
      if (bucket.first === bucket.last) return d.short(bucket.first)
      const last = d.month(bucket.last) === d.month(bucket.first) ? String(d.dayOfMonth(bucket.last)) : d.short(bucket.last)
      return `${d.short(bucket.first)}–${last}`
    })
  }

  axis(): string[] {
    const first = this.buckets[0]
    const middle = this.buckets[Math.floor(this.buckets.length / 2)]
    return [first ? d.short(first.first) : "", middle ? d.short(middle.first) : "", "Today"]
  }

  private inWindow(day: Day): boolean {
    return this.days[0] <= day && day <= this.days[1]
  }

  private top(rows: Row[]): [string, number][] {
    const keys = new Set(this.selected.map((page) => page.key))
    const sums = new Map<string, number>()
    for (const [page, day, label, count] of rows) {
      if (keys.has(page) && this.inWindow(day)) sums.set(label, (sums.get(label) ?? 0) + count)
    }
    return [...sums.entries()].sort((a, b) => b[1] - a[1] || compare(a[0], b[0]))
  }
}

// By code point, as Ruby sorts strings.
function compare(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0
}

function sum(values: number[]): number {
  return values.reduce((total, value) => total + value, 0)
}
