import type { Day } from "../dates"

export type Range = "30d" | "90d" | "12m" | "all"
export const RANGES: Range[] = ["30d", "90d", "12m", "all"]
export const RANGE_LABELS: Record<Range, string> = { "30d": "30 days", "90d": "90 days", "12m": "12 months", all: "All time" }
export const DEFAULT_RANGE: Range = "12m"

// The builder's projects, busiest of all time first; rank fixes the colour.
export type Project = { repo: string; name: string; rank: number }

// A shipped or published entry, in the builder's words.
export type Item = { id: number; date: Day; shipped: boolean; repo: string | null; title: string; runIn: string; url: string | null }

// What the server sends with a page: every public commit, by day and repo
// ("" for none), and every shipped or published entry, from the first one on.
export type ProgressData = {
  today: Day
  firstActivity: Day | null
  projects: Project[]
  commits: Record<Day, Record<string, number>>
  items: Item[]
  range: Range
  selected: string[]
}
