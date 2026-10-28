import { useState } from "react"
import type { FilterView, ProgressRange } from "../types"
import { useView, type Target } from "../useView"
import type { Focus } from "./CompareChart"
import type { NumberEvents } from "./NumberToggles"
import type { RowTargets } from "./ProjectsTable"
import { apiUrl, lineOrder, linesFrom, pageUrl, reconcile, toggled, type Lines, type Place } from "./lines"

// A chart filter's state, the same on every chart page: the view on screen,
// the line each drawn number wears, the line under the controls, the number
// or row whose lines come forward, and where each control goes. Each click
// asks the page's API for that view, warmed when the pointer or focus
// reaches it, and shows it in place; the page's URL follows, so the view
// stays shareable. The last number and the last row in view stay, and say so.

export type FilterOptions = {
  // The page's API, with any params of its own.
  endpoint: string
  defaultRange: ProgressRange
  // Whether the page's URL names the rows in view; a project's page is its project.
  named: boolean
  // Old params the page's URL drops once a view shows (pageUrl).
  dropped: string[]
}

type Next = { range?: ProgressRange; lines?: Lines; projects?: string[] }

export function useFilter<V extends FilterView>(initial: V, { endpoint, defaultRange, named, dropped }: FilterOptions) {
  const placeOf = (view: FilterView): Place => ({ range: view.range, show: view.drawn, projects: named ? view.selected : [] })
  const order = (view: FilterView) => view.numbers.map((number) => number.key)
  const { view, busy, failed, show, reload, retry, prefetch } = useView(initial, apiUrl(endpoint, placeOf(initial), order(initial)))
  const [kept, setKept] = useState<Lines>(() => linesFrom(initial.drawn))
  const [notice, setNotice] = useState("")
  const [focus, setFocus] = useState<Focus | null>(null)
  const lines = reconcile(kept, view.drawn)

  // The API's address and the page's own for a view.
  function urls(next: Next): [string, string] {
    const to: Place = { range: next.range ?? view.range, show: lineOrder(next.lines ?? lines), projects: named ? next.projects ?? view.selected : [] }
    const page = pageUrl(window.location.href, to, { range: defaultRange, show: view.defaultShow }, { projects: named, dropped })
    return [apiUrl(endpoint, to, order(view)), page]
  }

  // Any change of view clears the line under the controls.
  function to(next: Next): Target {
    const landed = next.lines ? () => setKept(next.lines ?? {}) : undefined
    return { go: () => { setNotice(""); show(...urls(next), landed) }, warm: () => prefetch(urls(next)[0]) }
  }

  function numberTarget(key: string): Target {
    const result = toggled(lines, key, view.numbers.find((number) => number.key === key)?.word ?? key)
    if ("notice" in result) return { go: () => setNotice(result.notice), warm: () => undefined }
    return to({ lines: result.lines })
  }

  const drawable = view.table?.rows.filter((row) => row.drawable).map((row) => row.repo) ?? []
  const inView = view.selected.length > 0 ? view.selected : drawable
  const rows: RowTargets = {
    box: (repo) => {
      const after = inView.includes(repo) ? inView.filter((each) => each !== repo) : drawable.filter((each) => inView.includes(each) || each === repo)
      if (after.length === 0) return null
      return to({ projects: after.length === drawable.length ? [] : after })
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
    // The same view again, past every view kept, after a change on the server.
    reload: () => reload(...urls({})),
  }
}
