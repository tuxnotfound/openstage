import { useState } from "react"
import type { FilterView, ProgressRange } from "../types"
import { useView, type Target } from "../useView"
import type { Focus } from "./CompareChart"
import type { NumberEvents } from "./NumberToggles"
import type { RowTargets } from "./ProjectsTable"
import { apiUrl, boxed, lineOrder, linesFrom, pageUrl, reconcile, toggled, within, type Lines } from "./lines"

// A chart filter's state, the same on every chart page: the view on screen,
// the line each drawn number wears, the line under the controls, the number
// or row whose lines come forward, and where each control goes. Each click
// asks the page's API for that view, warmed when the pointer or focus
// reaches it, and shows it in place; the page's URL follows once it lands,
// so the view stays shareable. A click builds on the view last asked for,
// so one that follows another before its view arrives keeps the first. The
// numbers asked for stay asked for while the page cannot draw them (none of
// its projects shows them any more), so one shown again comes back. The
// last number and the last row in view stay, and say so.

export type FilterOptions = {
  // The page's API, with any params of its own.
  endpoint: string
  defaultRange: ProgressRange
  // Whether the page's URL names the rows in view; a project's page is its project.
  named: boolean
  // Old params the page's URL drops once a view shows (pageUrl).
  dropped: string[]
}

// The view asked for: its window, the line each number asked for wears, and
// the rows in view, none for all of them.
type Wanted = { range: ProgressRange; lines: Lines; projects: string[] }

export function useFilter<V extends FilterView>(initial: V, { endpoint, defaultRange, named, dropped }: FilterOptions) {
  const order = (view: FilterView) => view.numbers.map((number) => number.key)
  const first: Wanted = { range: initial.range, lines: linesFrom(initial.drawn), projects: named ? initial.selected : [] }
  const address = (want: Wanted, numbers: string[]) => apiUrl(endpoint, { range: want.range, show: lineOrder(want.lines), projects: want.projects }, numbers)
  const { view, busy, failed, open, reload, retry, prefetch } = useView(initial, address(first, order(initial)))
  const [wanted, setWanted] = useState(first)
  const [notice, setNotice] = useState("")
  const [focus, setFocus] = useState<Focus | null>(null)
  const lines = reconcile(wanted.lines, view.drawn)
  const drawable = view.table?.rows.filter((row) => row.drawable).map((row) => row.repo) ?? []

  // The page's own address for the view that landed, against its defaults.
  const page = (want: Wanted) => (landed: V) =>
    pageUrl(window.location.href, { range: landed.range, show: lineOrder(reconcile(want.lines, landed.drawn)), projects: named ? landed.selected : [] },
            { range: defaultRange, show: landed.defaultShow }, { projects: named, dropped })

  // Asks for a view; again: past every view kept, after a change on the
  // server. The window and the rows follow the view that lands.
  function go(next: Wanted, again = false) {
    setNotice("")
    setWanted(next)
    const landed = (arrived: V) => setWanted((was) => ({ ...was, range: arrived.range, projects: named ? arrived.selected : [] }))
    ;(again ? reload : open)(address(next, order(view)), page(next), landed)
  }

  function to(change: Partial<Wanted>): Target {
    const next = { ...wanted, ...change }
    return { go: () => go(next), warm: () => prefetch(address(next, order(view))) }
  }

  // A toggle's click, from the numbers drawn or on their way.
  function numberTarget(key: string): Target {
    const asked = within(wanted.lines, order(view))
    const result = toggled(Object.keys(asked).length > 0 ? asked : lines, key, view.numbers.find((number) => number.key === key)?.word ?? key)
    if ("notice" in result) return { go: () => setNotice(result.notice), warm: () => undefined }
    return to({ lines: result.lines })
  }

  const rows: RowTargets = {
    box: (repo) => {
      const projects = boxed(repo, wanted.projects, drawable)
      return projects ? to({ projects }) : null
    },
    only: (repo) => to({ projects: [repo] }),
    all: view.selected.length > 0 ? to({ projects: [] }) : null,
    refuse: () => setNotice("The chart keeps at least one project."),
    focus: (repo) => setFocus(repo ? { kind: "project", key: repo } : null),
  }
  const numbers: NumberEvents = {
    toggle: (key) => numberTarget(key).go(),
    warm: (key) => numberTarget(key).warm(),
    focus: (key) => setFocus(key ? { kind: "number", key } : null),
  }

  return {
    view, busy, failed, retry, lines, notice, focus, rows, numbers,
    // The window's pills, beside whatever they scope.
    window: (range: ProgressRange) => to({ range }),
    // The view asked for again, past every view kept, after a change on the
    // server: a number switched back on is drawn again.
    reload: () => go(wanted, true),
  }
}
