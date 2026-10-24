import * as d from "../dates"
import type { Day } from "../dates"
import type { Item, Project, ProgressData, Range } from "./types"
import { Window } from "./window"
import type { ChartLine } from "../LineChart"

// What Progress::TallyService counts for a window and the projects in view:
// commits by project, shipped and published entries, active days, and the
// same over the stretch just before. With projects picked, only their
// commits and the entries tagged with them count.

export type Totals = {
  shipped: number
  published: number
  commits: number
  activeDays: number
  // Commits by repo, "" for none; the picked projects' only under a filter.
  counts: Record<string, number>
}

// Days averaged in the 30-day view.
const AVERAGE = 7

export class Tally {
  readonly window: Window
  readonly totals: Totals
  readonly previous: Totals | null
  readonly picked: Project[]

  constructor(readonly data: ProgressData, range: Range, readonly selected: string[]) {
    this.window = new Window(range, data.today, data.firstActivity)
    this.picked = data.projects.filter((project) => selected.includes(project.repo))
    this.totals = this.totalsOn(this.window.first, data.today)
    const comparison = this.window.comparison
    this.previous = comparison ? this.totalsOn(comparison[0], comparison[1]) : null
  }

  get filtered(): boolean {
    return this.selected.length > 0
  }

  shows(repo: string | null): boolean {
    return !this.filtered || (repo !== null && this.selected.includes(repo))
  }

  // The projects in view with commits, busiest of all time first.
  get shares(): { project: Project; commits: number }[] {
    return this.data.projects
      .map((project) => ({ project, commits: this.totals.counts[project.repo] ?? 0 }))
      .filter((share) => share.commits > 0)
  }

  get projectsWithCommits(): number {
    return Object.entries(this.totals.counts).filter(([repo, n]) => repo !== "" && n > 0).length
  }

  // Shipped and published in the window, in view, newest first.
  get items(): Item[] {
    return this.itemsOn(this.window.first, this.data.today).reverse()
  }

  get firstCommitDay(): Day | null {
    const days = d.each(this.window.first, this.data.today)
    return days.find((day) => Object.entries(this.data.commits[day] ?? {}).some(([repo, n]) => n > 0 && this.shows(repo || null))) ?? null
  }

  // "trained-on", "openstage + wheels-off", "3 projects"; or with
  // alternatives, "openstage or wheels-off", "any of these 3 projects".
  selectionName(alternatives = false): string {
    const names = this.picked.map((project) => project.name)
    if (names.length <= 2) return names.join(alternatives ? " or " : " + ")
    return alternatives ? `any of these ${names.length} projects` : `${names.length} projects`
  }

  // "all 7 projects", the picked ones, or the only one.
  get scope(): string {
    if (this.filtered) return this.selectionName()
    const all = this.data.projects
    return all.length === 1 ? (all[0]?.name ?? "") : `all ${all.length} projects`
  }

  // [arrow, words, up], as ProgressHelper#progress_change.
  get change(): [string | null, string, boolean | null] {
    const now = this.totals.commits
    const before = this.previous?.commits ?? 0
    if (this.previous && before > 0) {
      const change = roundHalfAway((100 * now) / before - 100)
      if (change === 0) return [null, `same as the previous ${this.window.span}`, null]
      return [change > 0 ? "▲" : "▼", `${Math.abs(change)}% ${this.window.versus}`, change > 0]
    }
    return [null, this.since(), null]
  }

  // One line per project in view with commits in the window.
  get lines(): ChartLine[] {
    return this.shares.map(({ project }) => ({ key: project.repo, name: project.name, rank: project.rank, values: this.valuesFor(project.repo) }))
  }

  get average(): boolean {
    return this.window.range === "30d"
  }

  get ariaLabel(): string {
    const what = this.average ? "7-day average of commits per day" : `Commits per ${this.window.unit}`
    return `${what} by project, ${this.window.words}`
  }

  get note(): string {
    return this.average ? "A 7-day average of commits per day, one line per project." : `Commits per ${this.window.unit}, one line per project.`
  }

  get emptyNote(): string {
    return `No commits ${this.window.word}${this.filtered ? ` for ${this.selectionName()}` : ""}.`
  }

  private since(): string {
    const first = this.firstCommitDay
    if (first && this.previous === null) {
      const day = `${d.longMonth(first)} ${d.dayOfMonth(first)}`
      return `since the first commit, ${d.year(first) === d.year(this.data.today) ? day : `${day}, ${d.year(first)}`}`
    }
    return this.previous ? `none in the previous ${this.window.span}` : ""
  }

  private valuesFor(repo: string): number[] {
    return this.window.buckets.map((bucket) => {
      if (!this.average) return d.each(bucket.first, bucket.last).reduce((sum, day) => sum + this.count(day, repo), 0)
      let sum = 0
      for (let back = 0; back < AVERAGE; back++) sum += this.count(d.addDays(bucket.first, -back), repo)
      return sum / AVERAGE
    })
  }

  private count(day: Day, repo: string): number {
    return this.data.commits[day]?.[repo] ?? 0
  }

  private totalsOn(from: Day, to: Day): Totals {
    const counts: Record<string, number> = {}
    const active = new Set<Day>()
    for (const day of d.each(from, to)) {
      for (const [repo, n] of Object.entries(this.data.commits[day] ?? {})) {
        if (n === 0 || !this.shows(repo || null)) continue
        counts[repo] = (counts[repo] ?? 0) + n
        active.add(day)
      }
    }
    const items = this.itemsOn(from, to)
    items.forEach((item) => active.add(item.date))
    return {
      shipped: items.filter((item) => item.shipped).length,
      published: items.filter((item) => !item.shipped).length,
      commits: Object.values(counts).reduce((sum, n) => sum + n, 0),
      activeDays: active.size,
      counts,
    }
  }

  private itemsOn(from: Day, to: Day): Item[] {
    return this.data.items.filter((item) => from <= item.date && item.date <= to && this.shows(item.repo))
  }
}

// Ruby's Float#round: half away from zero.
function roundHalfAway(value: number): number {
  return Math.sign(value) * Math.round(Math.abs(value))
}
