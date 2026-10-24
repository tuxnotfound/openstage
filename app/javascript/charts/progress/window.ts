import * as d from "../dates"
import type { Day } from "../dates"
import type { Range } from "./types"

// A stretch of the builder's work that ends today, as Progress::Window draws
// it: 30 days by day, 90 days by week (13 ISO weeks), 12 months by month, or
// all time by month; with its words, as Progress::WindowLabels says them.

export type Bucket = { index: number; first: Day; last: Day }
export type Unit = "day" | "week" | "month"

const SPANS: Record<Exclude<Range, "all">, string> = { "30d": "30 days", "90d": "90 days", "12m": "12 months" }

export class Window {
  readonly first: Day
  readonly buckets: Bucket[]

  constructor(readonly range: Range, readonly today: Day, readonly firstActivity: Day | null) {
    this.first = this.start()
    this.buckets = this.spans().map(([first, last], index) => ({ index, first, last }))
  }

  get unit(): Unit {
    return this.range === "30d" ? "day" : this.range === "90d" ? "week" : "month"
  }

  // The same stretch just before it, up to the same point; null for all
  // time, and when the work began inside the window.
  get comparison(): [Day, Day] | null {
    if (this.range === "all" || this.firstActivity === null || this.firstActivity >= this.first) return null
    return [this.back(this.first), this.back(this.today)]
  }

  bucketFor(day: Day): Bucket | undefined {
    return this.buckets.find((bucket) => bucket.first <= day && day <= bucket.last)
  }

  // "last 90 days", "since March 2026".
  get words(): string {
    return this.range === "all" ? `since ${d.longMonth(this.first)} ${d.year(this.first)}` : `last ${SPANS[this.range]}`
  }

  // "in the last 90 days"
  get word(): string {
    return this.range === "all" ? this.words : `in the ${this.words}`
  }

  get span(): string | null {
    return this.range === "all" ? null : SPANS[this.range]
  }

  get versus(): string | null {
    return this.span && `vs the previous ${this.span}`
  }

  get empty(): string {
    return `Nothing shipped or published ${this.word}.`
  }

  emptyTagged(project: string): string {
    return `No entries tagged ${project} ${this.word}.`
  }

  // Under the chart: "Jul 27", or "Oct", or "Nov 2025" for another year's month.
  axis(bucket: Bucket): string {
    if (this.unit !== "month") return d.short(bucket.first)
    return d.year(bucket.first) === d.year(this.today) ? d.monthName(bucket.first) : `${d.monthName(bucket.first)} ${d.year(bucket.first)}`
  }

  title(bucket: Bucket): string {
    if (this.unit === "day") return `${d.weekday(bucket.first)}, ${d.short(bucket.first)}`
    if (this.unit === "week") return `Week of ${spanWords(bucket.first, bucket.last)}`
    return `${d.longMonth(bucket.first)} ${d.year(bucket.first)}`
  }

  private start(): Day {
    switch (this.range) {
      case "30d": return d.addDays(this.today, -29)
      case "90d": return d.addDays(this.today, -(d.cwday(this.today) - 1) - 84)
      case "12m": return d.addMonths(d.monthStart(this.today), -11)
      default: return d.monthStart(this.firstActivity ?? this.today)
    }
  }

  private back(day: Day): Day {
    if (this.range === "30d") return d.addDays(day, -30)
    if (this.range === "90d") return d.addDays(day, -91)
    return d.addMonths(day, -12)
  }

  private spans(): [Day, Day][] {
    if (this.unit === "day") return d.each(this.first, this.today).map((day) => [day, day])
    const spans: [Day, Day][] = []
    for (let start = this.first; start <= this.today; start = this.unit === "week" ? d.addDays(start, 7) : d.addMonths(start, 1)) {
      spans.push([start, d.min(this.unit === "week" ? d.addDays(start, 6) : d.monthEnd(start), this.today)])
    }
    return spans
  }
}

function spanWords(from: Day, to: Day): string {
  if (from === to) return d.short(from)
  return d.month(from) === d.month(to) ? `${d.short(from)}–${d.dayOfMonth(to)}` : `${d.short(from)} – ${d.short(to)}`
}
