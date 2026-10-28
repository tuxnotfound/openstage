import type { CompareChartView, NumberView, Rank } from "../types"

// The chart filter's own rules in the browser, as the canvas boards drew
// them (chartkit.js): which line each drawn number takes and in what
// colour, what a toggle's click does, the note's line styles, the addresses
// of a view, where a line stands at a point, where the tooltip sits, and
// how many toggles fit a row. Every number comes from the server; this only
// arranges what it sent.

export const MAX_DRAWN = 3
// A number's line by its place in the line order: solid, dotted, dashed.
export const LINE_DASHES = ["", "2 9", "14 10"]
// The same three as a toggle's, a column's or the tooltip's sample.
export const KEY_DASHES = ["", "0.1 5.5", "7 4.5"]
const STYLES = ["solid", "dotted", "dashed"]
// The chart's box, as ProgressChart::Compare draws in it.
const HEIGHT = 280

// The line each drawn number takes, 0 to 2, by its key.
export type Lines = Record<string, number>

// The class that gives a line, a box or a dot its row's colour, as
// ProgressHelper#project_class: by rank, the seventh project on grey, and
// ink for none (the builder's own page, on analytics).
export function projectClass(rank: Rank): string {
  if (rank === null) return "os-project-none"
  return rank < 6 ? `os-project-${rank + 1}` : "os-project-other"
}

// The lines of the numbers drawn, in line order.
export function linesFrom(drawn: string[]): Lines {
  return Object.fromEntries(drawn.slice(0, MAX_DRAWN).map((key, i) => [key, i]))
}

// The lines once the server says which numbers it drew: each keeps its own,
// a new one takes the first free line, and one it no longer draws leaves.
export function reconcile(lines: Lines, drawn: string[]): Lines {
  const kept: Lines = {}
  drawn.forEach((key) => {
    const line = lines[key]
    if (line !== undefined) kept[key] = line
  })
  drawn.forEach((key) => {
    if (kept[key] === undefined) kept[key] = freeLine(kept)
  })
  return kept
}

function freeLine(lines: Lines): number {
  const used = Object.values(lines)
  return [0, 1, 2].find((line) => !used.includes(line)) ?? 0
}

// The lines of the numbers among some keys: what a page can draw of the
// numbers asked for.
export function within(lines: Lines, keys: string[]): Lines {
  return Object.fromEntries(Object.entries(lines).filter(([key]) => keys.includes(key)))
}

// The numbers drawn, in line order.
export function lineOrder(lines: Lines): string[] {
  return Object.entries(lines).sort(([, a], [, b]) => a - b).map(([key]) => key)
}

// The line a number wears: its own while the chart compares numbers; drawn
// alone, it is solid on its own axis.
export function lineOf(lines: Lines, key: string, indexed: boolean): number {
  return indexed ? lines[key] ?? 0 : 0
}

// What a toggle's click does: the lines after it, or what the chart says
// instead. The last number drawn stays, and three is the most.
export function toggled(lines: Lines, key: string, word: string): { lines: Lines } | { notice: string } {
  if (lines[key] !== undefined) {
    if (Object.keys(lines).length === 1) return { notice: "The chart keeps at least one number." }
    return { lines: Object.fromEntries(Object.entries(lines).filter(([each]) => each !== key)) }
  }
  if (Object.keys(lines).length >= MAX_DRAWN) return { notice: `The chart draws three numbers at most. Switch one off to draw ${word}.` }
  return { lines: { ...lines, [key]: freeLine(lines) } }
}

// The rows in view once a row's box is clicked, none for all of them; null
// when the last one in view would go. projects: the rows in view, none for
// all; all: every row with a box, in the table's order.
export function boxed(key: string, projects: string[], all: string[]): string[] | null {
  const inView = projects.length > 0 ? projects : all
  const after = inView.includes(key) ? inView.filter((each) => each !== key) : all.filter((each) => inView.includes(each) || each === key)
  if (after.length === 0) return null
  return after.length === all.length ? [] : after
}

// The note under the chart; one that compares numbers names each number's
// line by this page's own line order, between the server's words.
export function noteOf(chart: CompareChartView, numbers: NumberView[], lines: Lines): string {
  if (!chart.indexed || !chart.noteParts) return chart.note
  const names = chart.heads.map((key, i) => {
    const number = numbers.find((each) => each.key === key)
    return `${(i === 0 ? number?.label : number?.word) ?? key} ${STYLES[lines[key] ?? 0]}`
  })
  return `${chart.noteParts.before}${sentence(names)}${chart.noteParts.after}`
}

// "a", "a and b", "a, b and c".
export function sentence(words: string[]): string {
  if (words.length <= 1) return words.join("")
  return `${words.slice(0, -1).join(", ")} and ${words[words.length - 1]}`
}

// Where a line stands at each point, in percent from the chart's top, read
// from the path the server drew: one vertex per point.
export function pathTops(d: string, height = HEIGHT): number[] {
  return [...d.matchAll(/[ML]\s*-?[\d.]+\s+(-?[\d.]+)/g)].map((match) => (100 * Number(match[1])) / height)
}

// Where the tooltip's box starts, in pixels from the chart's left, for a
// point at x percent of a chart span pixels wide: beside the point, on its
// roomier side, while the box fits there; else against the chart's nearer
// edge, so it never runs past the chart, nor off a phone's screen.
export function tipLeft(x: number, width: number, span: number, gap = 14, edge = 4): number {
  const at = (x / 100) * span
  const beside = x > 50 ? at - gap - width : at + gap
  return Math.round(Math.max(edge, Math.min(beside, span - width - edge)))
}

// A group of toggles as the row measures it: its label's width (0 for a
// row without groups) and each toggle's.
export type Measured = { label: number; toggles: number[] }

// How many toggles fit a row of a width, in as many lines as it may take
// (one on a wide screen; on a phone the toggles wrap); when not all of them
// do, the "+ n more" button takes its place after them. The row wraps as
// flex-wrap does: a group, or in a row without groups a toggle, that does
// not fit beside the last starts a line. Groups fold whole, so a group never
// splits across the rows, unless not even the first one fits: then its
// toggles fit one line one by one. gap: between toggles, and after a
// group's label; groupGap: between groups, and before the button.
export function fitting(groups: Measured[], more: number, width: number, gap: number, groupGap = gap, lines = 1): number {
  const labelled = groups.some((group) => group.label > 0)
  const span = (group: Measured) => (group.label ? group.label + gap : 0) + sum(group.toggles) + gap * Math.max(0, group.toggles.length - 1)
  const items = labelled ? groups.map(span) : groups.flatMap((group) => group.toggles)
  const step = labelled ? groupGap : gap
  const count = sum(groups.map((group) => group.toggles.length))
  if (linesFor(items, width, step) <= lines) return count
  let whole = 0
  while (whole < items.length && linesFor([...items.slice(0, whole + 1), more], width, step) <= lines) whole += 1
  if (!labelled) return Math.max(1, whole)
  if (whole > 0) return sum(groups.slice(0, whole).map((group) => group.toggles.length))
  const first = groups[0]
  let used = more + groupGap + (first?.label ? first.label + gap : 0) - gap
  let fit = 0
  for (const each of first?.toggles ?? []) {
    if (used + gap + each > width) break
    used += gap + each
    fit += 1
  }
  return Math.max(1, fit)
}

// The lines some items take in a row of a width, each gap apart, as
// flex-wrap places them; Infinity when one is wider than the row.
function linesFor(items: number[], width: number, gap: number): number {
  let lines = 0
  let used = 0
  for (const item of items) {
    if (item > width) return Infinity
    if (lines > 0 && used + gap + item <= width) {
      used += gap + item
    } else {
      lines += 1
      used = item
    }
  }
  return lines
}

function sum(values: number[]): number {
  return values.reduce((total, each) => total + each, 0)
}

// A view as the page's URL and the API's name it.
export type Place = { range: string; show: string[]; projects: string[] }

// The API's address for a view: the endpoint's own params, then the window,
// the numbers (in the pages' order, since the view is the same in any) and
// the projects in view.
export function apiUrl(endpoint: string, place: Place, order: string[]): string {
  const [path, own = ""] = endpoint.split("?")
  const query = new URLSearchParams(own)
  query.set("range", place.range)
  query.set("show", [...place.show].sort((a, b) => rank(order, a) - rank(order, b)).join(","))
  if (place.projects.length) query.set("projects", place.projects.join(","))
  return `${path}?${query.toString()}`
}

function rank(order: string[], key: string): number {
  const at = order.indexOf(key)
  return at === -1 ? order.length : at
}

// The page's own address for a view: its other params stay (the
// dashboard's entry filters, a linked entry), and the window, the numbers in
// line order and the projects stay out at the page's defaults. projects:
// whether the page's URL names the rows in view; dropped: the old params it
// drops, as the view's own now name what they named (a builder's page's
// repo[], analytics' pages[] and metric).
export function pageUrl(href: string, place: Place, defaults: { range: string; show: string[] }, own: { projects: boolean; dropped: string[] }): string {
  const url = new URL(href)
  const query = url.searchParams
  ;["range", "show", "projects", ...own.dropped].forEach((key) => query.delete(key))
  if (place.range !== defaults.range) query.set("range", place.range)
  if (place.show.join(",") !== defaults.show.join(",")) query.set("show", place.show.join(","))
  if (own.projects && place.projects.length) query.set("projects", place.projects.join(","))
  const search = query.toString().replace(/%2C/gi, ",").replace(/%2F/gi, "/")
  return `${url.pathname}${search ? `?${search}` : ""}${url.hash}`
}
