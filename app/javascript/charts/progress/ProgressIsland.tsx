import { useEffect, useState, type ReactNode } from "react"
import { createPortal } from "react-dom"
import LineChart, { projectClass } from "../LineChart"
import Switches, { type Target } from "../Switches"
import { useView } from "../useView"
import type { ChartNumber, ChartView, LinesRow, LinesView, ProgressRange, ProgressView, ShippedItem } from "../types"

// The commit chart and what it counts, on a builder's page, a project's page
// and the dashboard, with the site visits each shows beside the commits. A
// click asks Api::ProgressController for that view and shows it in place; the
// page's URL follows, so the view stays shareable. Switching a number needs no
// request: the view carries a chart for each.

export type ProgressProps = {
  initial: ProgressView
  // Api::ProgressController's path for this builder, with any params of its
  // own (a hidden project's, for its builder).
  endpoint: string
  mode: "page" | "project" | "dashboard"
  // The numbers on at first, on a page with site visits.
  numbers?: ChartNumber[]
  defaultRange: ProgressRange
  // The What shipped section to keep in step, by element id.
  shippedTarget?: string
}

const RANGES: [ProgressRange, string][] = [["30d", "30 days"], ["90d", "90 days"], ["12m", "12 months"], ["all", "All time"]]
const SHOWN = 8
const NUMBERS: [ChartNumber, string][] = [["commits", "Commits"], ["visits", "Site visits"]]

export default function ProgressIsland({ initial, endpoint, mode, numbers: initialNumbers = ["commits", "visits"], defaultRange, shippedTarget }: ProgressProps) {
  const { view, busy, failed, show, reload, retry, prefetch } = useView(initial, apiUrl(endpoint, initial.range, initial.selected))
  const [picked, setPicked] = useState<ChartNumber[]>(initialNumbers)
  // The dashboard draws what each project picked; the pages, the toggles' choice.
  const numbers: ChartNumber[] = !view.site ? ["commits"] : mode === "dashboard" ? ["commits", "visits"] : picked

  // The last number on stays on; the URL names the only one on, or none for both.
  function toggle(number: ChartNumber) {
    const next = NUMBERS.map(([each]) => each).filter((each) => (each === number ? !numbers.includes(each) : numbers.includes(each)))
    if (next.length === 0) return
    setPicked(next)
    const url = new URL(window.location.href)
    if (next.length === 1) url.searchParams.set("show", next[0] ?? "commits")
    else url.searchParams.delete("show")
    window.history.replaceState(window.history.state, "", url)
  }

  // The API's address and the page's own for a view: the page keeps its
  // other params (the dashboard's entry filters, a linked entry).
  function urls(range: ProgressRange, selected: string[]): [string, string] {
    const page = new URLSearchParams(window.location.search)
    page.delete("range")
    if (range !== defaultRange) page.set("range", range)
    if (mode === "page") {
      page.delete("repo")
      page.delete("repo[]")
      selected.forEach((repo) => page.append("repo[]", repo))
    }
    const query = page.toString()
    return [apiUrl(endpoint, range, selected), `${window.location.pathname}${query ? `?${query}` : ""}${window.location.hash}`]
  }

  const to = (range: ProgressRange, selected: string[]): Target => ({
    go: () => show(...urls(range, selected)),
    warm: () => prefetch(urls(range, selected)[0]),
  })

  const pills = (
    <div className="os-pills" role="group" aria-label="Time range">
      {RANGES.map(([range, label]) => {
        const target = to(range, view.selected)
        return (
          <button key={range} type="button" className="os-pill max-sm:px-2" aria-pressed={range === view.range}
                  onClick={target.go} onPointerEnter={target.warm} onFocus={target.warm}>{label}</button>
        )
      })}
    </div>
  )
  const lines = useLineSwitches(view.lines, () => reload(...urls(view.range, view.selected)))
  const chart = mode === "dashboard" && lines.view
    ? <LineChart chart={lines.chart} height="h-[260px]" />
    : <LineChart chart={chartFor(view, numbers)} height={mode === "dashboard" ? "h-[260px]" : ""} legend={mode === "dashboard"} />
  const toggles = view.site && mode !== "dashboard" ? <NumberToggles view={view} numbers={numbers} toggle={toggle} /> : null
  const shipped = shippedTarget ? document.getElementById(shippedTarget) : null

  return (
    <div aria-busy={busy} className={`transition-opacity ${busy ? "opacity-60" : ""}`}>
      {mode === "page" && (
        <>
          <PageHeadline view={view} />
          <div className={`mt-6 grid items-start gap-x-8 gap-y-6 ${view.projects.length > 1 ? "lg:grid-cols-[minmax(0,1fr)_280px]" : ""}`}>
            <div className="min-w-0">
              <div className="flex flex-wrap items-end justify-between gap-3">{toggles}<div className="ml-auto">{pills}</div></div>
              <div className="mt-[22px]">{chart}</div>
            </div>
            {view.projects.length > 1 && <ProjectSwitches view={view} to={to} />}
          </div>
        </>
      )}
      {mode === "project" && <ProjectNumbers view={view} numbers={numbers} toggles={toggles} pills={pills} chart={chart} />}
      {mode === "dashboard" && (
        <>
          <div className="os-between">
            <h2 id="your-activity" className="os-h2">Your activity</h2>
            {pills}
          </div>
          <div className="mt-3 flex flex-wrap items-baseline gap-x-3.5 gap-y-1">
            <span className="os-num text-[56px] leading-none">{view.commits}</span>
            <span className="os-ink2">
              commits, {view.words}{view.change.words && <> · <Arrow view={view} /> {view.change.words}</>}{view.lines?.visits && <> · {view.lines.visits} site visits</>}
            </span>
          </div>
          <div className="mt-3.5">{chart}</div>
          {lines.view && <LinesTable lines={lines} words={view.words} range={view.range === defaultRange ? null : view.range} />}
        </>
      )}
      {failed && (
        <p role="status" className="os-note mt-3">
          That view did not load. <button type="button" className="os-link text-[13px]" onClick={retry}>Try again</button>
        </p>
      )}
      {shipped && createPortal(<Shipped view={view} />, shipped)}
    </div>
  )
}

function apiUrl(endpoint: string, range: ProgressRange, selected: string[]): string {
  const [path, own = ""] = endpoint.split("?")
  const query = new URLSearchParams(own)
  query.set("range", range)
  selected.forEach((repo) => query.append("repo[]", repo))
  return `${path}?${query.toString()}`
}

function Arrow({ view }: { view: ProgressView }) {
  const { arrow, up } = view.change
  if (!arrow) return null
  return <span className={up ? "text-up" : "text-down"} aria-label={up ? "Up" : "Down"}>{arrow}</span>
}

// The dashboard's table switches: a switch answers at once, and its line
// leaves the chart at once; the save goes to the server, which then draws
// the chart again on its new scale. A failed save puts the switch back.
type LineSwitches = {
  view: LinesView | null
  chart: ChartView
  on: (row: LinesRow, number: ChartNumber) => boolean
  flip: (row: LinesRow, number: ChartNumber) => void
  failed: boolean
}

function useLineSwitches(view: LinesView | null, redraw: () => void): LineSwitches {
  const [pending, setPending] = useState<Record<string, boolean>>({})
  const [failed, setFailed] = useState(false)

  // A switch the server now agrees with is no longer pending.
  useEffect(() => {
    if (!view) return
    setPending((was) => Object.fromEntries(Object.entries(was).filter(([key, on]) => {
      const [repo, number] = key.split("|")
      const row = view.rows.find((each) => each.repo === repo)
      return row ? row[number as ChartNumber].on !== on : false
    })))
  }, [view])

  const key = (row: LinesRow, number: ChartNumber) => `${row.repo}|${number}`
  const on = (row: LinesRow, number: ChartNumber) => pending[key(row, number)] ?? row[number].on

  async function flip(row: LinesRow, number: ChartNumber) {
    if (!row.switch) return
    const next = !on(row, number)
    const which = key(row, number)
    setFailed(false)
    setPending((was) => ({ ...was, [which]: next }))
    const response = await fetch(row.switch, {
      method: "PATCH", credentials: "same-origin",
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": csrfToken() },
      body: JSON.stringify({ number, shown: next }),
    }).catch(() => null)
    if (response?.ok) return redraw()
    setPending((was) => Object.fromEntries(Object.entries(was).filter(([each]) => each !== which)))
    setFailed(true)
  }

  const chart = view ? { ...view.chart, paths: view.chart.paths.filter((path) => !(path.key && pending[path.key] === false)) } : null
  return { view, chart: chart ?? emptyChart, on, flip, failed }
}

function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""
}

const emptyChart: ChartView = {
  paths: [], ticks: [], columns: [], axis: [], ariaLabel: "", note: "", emptyNote: "", none: "", empty: true, average: false, legend: [],
}

// Your projects, under the dashboard's chart: each with Edit, whether the
// builder's page shows it, and a cell per number with the window's value and
// its switch. Hiding a project from the page is a form, as the page reloads
// without its line. On a phone each row stacks, each switch under its label.
function LinesTable({ lines, words, range }: { lines: LineSwitches; words: string; range: ProgressRange | null }) {
  if (!lines.view) return null
  if (lines.view.rows.length === 0) {
    return <div className="mt-5" id="activity-lines"><p className="os-sm os-ink2">No repo has commits here yet. Your public repos appear once the first sync is done.</p></div>
  }
  return (
    <div className="mt-5" id="activity-lines">
      <table className="w-full table-fixed border-collapse text-sm max-sm:block">
        <caption className="sr-only">Your projects: what your page and this chart show of each</caption>
        <thead className="max-sm:hidden">
          <tr className="text-xs text-ink-3">
            <th scope="col" className="py-2 text-left font-bold">Your projects</th>
            <th scope="col" className="w-24 py-2 text-right font-bold">Your page</th>
            {NUMBERS.map(([number, label]) => (
              <th key={number} scope="col" className="w-34 py-2 text-right font-bold">
                <span className="inline-flex items-center gap-1.5"><LineSample number={number} />{label}</span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="max-sm:block">
          {lines.view.rows.map((row) => {
            const off = row.page !== null && !row.page.on
            return (
              <tr key={row.repo} className="border-t border-line max-sm:grid max-sm:grid-cols-3 max-sm:gap-x-3 max-sm:gap-y-2.5 max-sm:py-3" data-line-row={row.repo}>
                <th scope="row" className="py-2.5 text-left font-bold max-sm:col-span-3 max-sm:py-0">
                  <span className="flex min-w-0 items-center gap-2.5">
                    <span className={`os-dot ${projectClass(row.rank)} shrink-0 bg-(--project) ${off ? "opacity-40" : ""}`} />
                    <span className={`truncate ${off ? "text-ink-3" : ""}`}>{row.name}</span>
                    {row.edit && <a href={row.edit} className="os-btn2 sm shrink-0" aria-label={`Edit ${row.name}`}>Edit</a>}
                  </span>
                </th>
                <td className="py-2.5 text-right max-sm:py-0 max-sm:text-left">
                  <span className="os-xs os-muted mb-1 block sm:hidden">Your page</span>
                  {row.page && <PageSwitch row={row} page={row.page} range={range} />}
                </td>
                {NUMBERS.map(([number, label]) => (
                  <td key={number} className="py-2.5 text-right max-sm:py-0 max-sm:text-left">
                    <span className="os-xs os-muted mb-1 block sm:hidden">{label}</span>
                    <LineCellView lines={lines} row={row} number={number} label={label} />
                  </td>
                ))}
              </tr>
            )
          })}
        </tbody>
      </table>
      {lines.failed && <p role="status" className="os-note mt-2">That switch did not save. Try it again.</p>}
      <p className="os-note mt-2">Values are the {words}. The switches set what visitors see on your page and your project pages, and this chart follows them.</p>
    </div>
  )
}

function LineSample({ number }: { number: ChartNumber }) {
  return <span className={`w-3.5 border-t-[3px] border-current ${number === "visits" ? "border-dotted" : ""}`} aria-hidden="true" />
}

// GithubReposController switches it and sends the dashboard back.
function PageSwitch({ row, page, range }: { row: LinesRow; page: { on: boolean; path: string }; range: ProgressRange | null }) {
  return (
    <form method="post" action={page.path} className="inline-flex" data-turbo="false">
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" value={csrfToken()} />
      <input type="hidden" name="included" value={String(!page.on)} />
      {range && <input type="hidden" name="range" value={range} />}
      <button type="submit" role="switch" aria-checked={page.on} aria-label={`Show ${row.name} on your page`} className="os-switch" />
    </form>
  )
}

function LineCellView({ lines, row, number, label }: { lines: LineSwitches; row: LinesRow; number: ChartNumber; label: string }) {
  const cell = row[number]
  const on = lines.on(row, number)
  if (cell.setup) {
    return (
      <a href={cell.setup} aria-label={`Set up ${row.name}'s site visits`}
         className="inline-flex h-[22px] items-center rounded-full border border-line px-2.5 text-[11px] font-bold text-ink-2 hover:border-accent hover:text-accent-ink">Set up</a>
    )
  }
  if (cell.value === null) return <span className="os-xs os-muted">–</span>
  if (row.switch === null) return <span className="os-num tabular-nums">{cell.value}</span>
  return (
    <span className="inline-flex items-center gap-2.5">
      <span className={`os-num tabular-nums ${on ? "text-ink" : "text-ink-3"}`}>{cell.value}</span>
      <button type="button" role="switch" aria-checked={on} aria-label={`Show ${label.toLowerCase()} for ${row.name}`} className="os-switch"
              onClick={() => lines.flip(row, number)} />
    </span>
  )
}

// The chart for the numbers on: commits alone, visits alone, or both.
function chartFor(view: ProgressView, numbers: ChartNumber[]): ChartView {
  if (!view.site || (numbers.length === 1 && numbers[0] === "commits")) return view.chart
  return numbers.length === 1 ? view.site.chart : view.site.compare
}

// A toggle per number, with its value and its line: commits solid, visits dotted.
function NumberToggles({ view, numbers, toggle }: { view: ProgressView; numbers: ChartNumber[]; toggle: (number: ChartNumber) => void }) {
  const values: Record<ChartNumber, string> = { commits: String(view.commits), visits: view.site?.value ?? "" }
  return (
    <div className="os-pills flex-wrap" role="group" aria-label="Numbers">
      {NUMBERS.map(([number, label]) => (
        <button key={number} type="button" className="os-pill gap-2 px-3.5" aria-pressed={numbers.includes(number)} onClick={() => toggle(number)}>
          <LineSample number={number} />
          <span>{label}</span>
          <span className="os-num text-[15px]">{values[number]}</span>
        </button>
      ))}
    </div>
  )
}

// A project's page: the toggles above the chart, and the number on when only one is.
function ProjectNumbers({ view, numbers, toggles, pills, chart }: {
  view: ProgressView; numbers: ChartNumber[]; toggles: ReactNode; pills: ReactNode; chart: ReactNode
}) {
  const only = numbers.length === 1 ? numbers[0] : null
  const headline = (
    <>
      <p className="os-label">{only === "visits" ? "Site visits" : only === "commits" ? "Commits" : "Commits and site visits"} · {view.words}</p>
      {only === "visits" && view.site && (
        <div className="mt-0.5 flex flex-wrap items-baseline gap-x-[22px] gap-y-1.5">
          <span className="os-num os-big">{view.site.value}</span>
          <span className="text-lg font-semibold text-ink-2">{view.site.visitors}</span>
        </div>
      )}
      {only === "commits" && <Headcount view={view} />}
    </>
  )
  // With site visits, the numbers and the window share one row, and what the chart shows sits under them.
  return (
    <>
      {toggles ? (
        <>
          <div className="mt-7 flex flex-wrap items-center justify-between gap-3">{toggles}{pills}</div>
          <div className="mt-5">{headline}</div>
        </>
      ) : (
        <div className="os-between mt-7.5 items-end"><div>{headline}</div>{pills}</div>
      )}
      <div className="mt-[22px]">{chart}</div>
    </>
  )
}

function Headcount({ view }: { view: ProgressView }) {
  return (
    <div className="mt-0.5 flex flex-wrap items-baseline gap-x-[22px] gap-y-1.5">
      <span className="os-num os-big">{view.commits}</span>
      {view.change.words && <span className="text-lg font-semibold text-ink-2"><Arrow view={view} /> {view.change.words}</span>}
    </div>
  )
}

function PageHeadline({ view }: { view: ProgressView }) {
  return (
    <div className="mt-[26px]">
      <p className="os-label">Commits · {view.scope}, {view.words}</p>
      <Headcount view={view} />
      {view.shares.length > 0 && (
        <>
          <div className="os-sharebar mt-5" role="img" aria-label="Share of commits by project">
            {view.shares.map((share) => (
              <div key={share.repo} className={`${projectClass(share.rank)} min-w-1.5 bg-(--project)`} style={{ flex: `${share.commits} 1 0` }}
                   title={`${share.name}: ${share.commits} ${share.commits === 1 ? "commit" : "commits"}`} />
            ))}
          </div>
          <div className="mt-2 flex flex-wrap gap-x-5 gap-y-1 text-[13px] text-ink-2">
            {view.shares.map((share) => (
              <span key={share.repo}><span className="os-num font-bold text-ink">{share.percent}%</span> {share.name}</span>
            ))}
          </div>
        </>
      )}
      <p className="os-xs os-muted mt-3">{view.kpis}</p>
    </div>
  )
}

// Beside the chart, a switch per project: with every project in view,
// switching one leaves the others; all of them on again means all.
function ProjectSwitches({ view, to }: { view: ProgressView; to: (range: ProgressRange, selected: string[]) => Target }) {
  const all = view.projects.map((project) => project.repo)
  const toggled = (repo: string) => {
    const picked = view.filtered ? view.selected : all
    const next = picked.includes(repo) ? picked.filter((each) => each !== repo) : [...picked, repo]
    return next.length === 0 || next.length === all.length ? [] : all.filter((each) => next.includes(each))
  }

  return (
    <Switches label="Projects" target={(repo) => to(view.range, toggled(repo))} all={view.filtered ? to(view.range, []) : null}
              items={view.projects.map((project) => ({ key: project.repo, name: project.name, rank: project.rank, on: project.on, value: project.value }))} />
  )
}

function Shipped({ view }: { view: ProgressView }) {
  const [all, setAll] = useState(false)
  const items = view.shipped.items
  return (
    <>
      <div className="os-between">
        <h2 id="what-shipped" className="os-h2">What shipped</h2>
        <span className="os-xs os-muted">{view.shipped.heading}</span>
      </div>
      {items.length === 0 ? (
        <p className="os-note mt-3">{view.shipped.empty}</p>
      ) : (
        <div className="mt-2.5">
          {(all ? items : items.slice(0, SHOWN)).map((item) => <ShippedRow key={item.id} item={item} />)}
          {!all && items.length > SHOWN && <button type="button" className="os-btn2 sm mt-3" onClick={() => setAll(true)}>Show all {items.length}</button>}
        </div>
      )}
    </>
  )
}

function ShippedRow({ item }: { item: ShippedItem }) {
  return (
    <div id={item.anchor ?? undefined} className="os-row os-rowflex scroll-mt-6 py-3">
      <span className="os-sm os-muted flex-[0_0_64px]">{item.date}</span>
      <span className="os-xs flex-[0_0_84px] font-bold text-ink-3">{item.kind}</span>
      <span className="min-w-0 flex-[1_1_300px] text-[15px] font-semibold">
        {item.url ? <a href={`/e/${item.id}/out`} target="_blank" rel="noopener" data-turbo="false" className="hover:underline" title={item.url}>{item.title}</a> : item.title}
        {item.runIn && <span className="font-normal text-ink-3">{item.runIn}</span>}
      </span>
      {item.project && <span className="os-xs os-muted">{item.project}</span>}
    </div>
  )
}
