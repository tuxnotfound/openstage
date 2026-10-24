import { readFileSync } from "node:fs"
import { describe, expect, test } from "vitest"
import { Tally } from "../../app/javascript/charts/progress/tally"
import type { ProgressData, Range } from "../../app/javascript/charts/progress/types"
import { Report, type AnalyticsData, type Metric, type Range as AnalyticsRange } from "../../app/javascript/charts/analytics/report"

// The browser's numbers against the server's, for the fixtures an RSpec spec
// writes (spec/requests/chart_parity_spec.rb): every window, and a few picks.

type ProgressCase = {
  range: Range; selected: string[]
  commits: number; previous: number | null; shipped: number; published: number; activeDays: number; projects: number
  scope: string; change: string; items: number; lines: Record<string, number[]>
}
type AnalyticsCase = {
  range: AnalyticsRange; metric: Metric; picked: string[]
  totals: Record<Metric, number>; changes: Record<Metric, number | null>
  sources: [string, number][]; countries: [string, number][]; links: [string, string, number][]; badges: [string, number, number][]
}

const path = process.env.PARITY_FIXTURE
const fixture = path ? JSON.parse(readFileSync(path, "utf8")) : null

describe.skipIf(!fixture)("the charts' numbers match the server's", () => {
  test.each((fixture?.progress?.cases ?? []) as ProgressCase[])("progress $range $selected", (expected) => {
    const tally = new Tally(fixture.progress.data as ProgressData, expected.range, expected.selected)
    const [arrow, words] = tally.change
    expect({
      commits: tally.totals.commits, previous: tally.previous?.commits ?? null, shipped: tally.totals.shipped,
      published: tally.totals.published, activeDays: tally.totals.activeDays, projects: tally.projectsWithCommits,
      scope: tally.scope, change: [arrow, words].filter(Boolean).join(" "), items: tally.items.length,
      lines: Object.fromEntries(tally.lines.map((line) => [line.key, line.values.map((value) => Math.round(value * 1000) / 1000)])),
    }).toEqual({
      commits: expected.commits, previous: expected.previous, shipped: expected.shipped, published: expected.published,
      activeDays: expected.activeDays, projects: expected.projects, scope: expected.scope, change: expected.change,
      items: expected.items, lines: expected.lines,
    })
  })

  test.each((fixture?.analytics?.cases ?? []) as AnalyticsCase[])("analytics $range $metric $picked", (expected) => {
    const report = new Report(fixture.analytics.data as AnalyticsData, expected.range, expected.metric, expected.picked)
    const metrics: Metric[] = ["visitors", "views", "follows", "clicks"]
    expect({
      totals: Object.fromEntries(metrics.map((metric) => [metric, report.total(metric)])),
      changes: Object.fromEntries(metrics.map((metric) => [metric, report.change(metric)])),
      sources: report.sources, countries: report.countries,
      links: report.links.map((link) => [link.title, link.page.key, link.count]), badges: report.badges,
    }).toEqual({ totals: expected.totals, changes: expected.changes, sources: expected.sources, countries: expected.countries, links: expected.links, badges: expected.badges })
  })
})
