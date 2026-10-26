import { useState } from "react"
import { createPortal } from "react-dom"
import LineChart, { projectClass } from "../LineChart"
import Switches, { type Target } from "../Switches"
import { useView } from "../useView"
import type { NumberView, ProgressRange, ProgressView, ProjectsRow, ProjectsTable, ShippedItem } from "../types"

// The numbers of a builder's work and its reach, on their page, a project's
// page and the dashboard: every number the view has, the picked ones charted
// a chart each on its own scale, stacked on the same points with one hover
// line through them. A click asks Api::ProgressController for that view and
// shows it in place; the page's URL follows, so the view stays shareable.

export type ProgressProps = {
  initial: ProgressView
  // Api::ProgressController's path for this builder, with any params of its
  // own (a hidden project's, for its builder; the dashboard's).
  endpoint: string
  mode: "page" | "project" | "dashboard"
  defaultRange: ProgressRange
  // The What shipped section to keep in step, by element id.
  shippedTarget?: string
}

const RANGES: [ProgressRange, string][] = [["30d", "30 days"], ["90d", "90 days"], ["12m", "12 months"], ["all", "All time"]]
const SHOWN = 8

type View = { range: ProgressRange; selected: string[]; numbers: string[] }

export default function ProgressIsland({ initial, endpoint, mode, defaultRange, shippedTarget }: ProgressProps) {
  const { view, busy, failed, show, retry, prefetch } = useView(initial, apiUrl(endpoint, current(initial)))
  const now = current(view)

  // The API's address and the page's own for a view: the page keeps its
  // other params (the dashboard's entry filters, a linked entry).
  function urls(next: View): [string, string] {
    const page = new URLSearchParams(window.location.search)
    page.delete("range")
    if (next.range !== defaultRange) page.set("range", next.range)
    if (mode !== "project") {
      page.delete("repo[]")
      next.selected.forEach((repo) => page.append("repo[]", repo))
    }
    page.delete("show[]")
    next.numbers.forEach((number) => page.append("show[]", number))
    const query = page.toString()
    return [apiUrl(endpoint, next), `${window.location.pathname}${query ? `?${query}` : ""}${window.location.hash}`]
  }

  const to = (change: Partial<View>): Target => {
    const next = { ...now, ...change }
    return { go: () => show(...urls(next)), warm: () => prefetch(urls(next)[0]) }
  }

  const pills = (
    <div className="os-pills" role="group" aria-label="Time range">
      {RANGES.map(([range, label]) => {
        const target = to({ range })
        return (
          <button key={range} type="button" className="os-pill max-sm:px-2" aria-pressed={range === view.range}
                  onClick={target.go} onPointerEnter={target.warm} onFocus={target.warm}>{label}</button>
        )
      })}
    </div>
  )
  const numbers = <NumbersLine view={view} to={(picked) => to({ numbers: picked })} />
  const stack = <ChartStack numbers={view.numbers} />
  const shipped = shippedTarget ? document.getElementById(shippedTarget) : null

  return (
    <div aria-busy={busy} className={`transition-opacity ${busy ? "opacity-60" : ""}`}>
      {mode === "page" && (
        <>
          <PageHeadline view={view} />
          <div className={`mt-6 grid items-start gap-x-8 gap-y-6 ${view.projects.length > 1 ? "lg:grid-cols-[minmax(0,1fr)_280px]" : ""}`}>
            <div className="min-w-0">
              <div className="flex flex-wrap items-center justify-between gap-3">{numbers}<div className="ml-auto">{pills}</div></div>
              <div className="mt-5">{stack}</div>
            </div>
            {view.projects.length > 1 && <ProjectSwitches view={view} to={(selected) => to({ selected })} />}
          </div>
        </>
      )}
      {mode === "project" && (
        <>
          <div className="mt-7 flex flex-wrap items-center justify-between gap-3">{numbers}{pills}</div>
          <div className="mt-5">{stack}</div>
        </>
      )}
      {mode === "dashboard" && (
        <>
          <div className="os-between">
            <h2 id="your-activity" className="os-h2">Your activity</h2>
            {pills}
          </div>
          <div className="mt-4">{numbers}</div>
          <div className="mt-5">{stack}</div>
          {view.table && <ProjectsTableView view={view} table={view.table} chart={(repo) => to({ selected: toggledProjects(view, repo) })}
                                            range={view.range === defaultRange ? null : view.range} />}
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

// The view's own range, projects and numbers; numbers empty while all are charted.
function current(view: ProgressView): View {
  const on = view.numbers.filter((number) => number.on).map((number) => number.key)
  return { range: view.range, selected: view.selected, numbers: on.length === view.numbers.length ? [] : on }
}

function apiUrl(endpoint: string, next: View): string {
  const [path, own = ""] = endpoint.split("?")
  const query = new URLSearchParams(own)
  query.set("range", next.range)
  next.selected.forEach((repo) => query.append("repo[]", repo))
  next.numbers.forEach((number) => query.append("numbers[]", number))
  return `${path}?${query.toString()}`
}

// With every project in view, switching one leaves the others; the last one
// stays, and every one on again means all of them.
function toggledProjects(view: ProgressView, repo: string): string[] {
  const all = view.projects.map((project) => project.repo)
  const picked = view.filtered ? view.selected : all
  const next = picked.includes(repo) ? picked.filter((each) => each !== repo) : [...picked, repo]
  if (next.length === 0) return view.selected
  return next.length === all.length ? [] : all.filter((each) => next.includes(each))
}

// Every number the view has with its total: the charted ones in ink and
// underlined, the others muted. Each switches its chart; the last stays.
function NumbersLine({ view, to }: { view: ProgressView; to: (picked: string[]) => Target }) {
  const on = view.numbers.filter((number) => number.on).map((number) => number.key)
  const toggled = (key: string) => {
    const next = on.includes(key) ? on.filter((each) => each !== key) : view.numbers.map((number) => number.key).filter((each) => each === key || on.includes(each))
    return next.length === 0 ? on : next.length === view.numbers.length ? [] : next
  }
  return (
    <div className="flex flex-wrap items-baseline gap-x-5 gap-y-1.5" role="group" aria-label="Numbers">
      {view.numbers.map((number) => {
        const target = to(toggled(number.key))
        return (
          <button key={number.key} type="button" aria-pressed={number.on} onClick={target.go} onPointerEnter={target.warm} onFocus={target.warm}
                  className={`inline-flex cursor-pointer items-baseline gap-1.5 border-b-2 bg-transparent pb-0.5 ${number.on ? "border-accent text-ink" : "border-transparent text-ink-3 hover:text-ink"}`}>
            <span className="text-sm font-bold">{number.label}</span>
            <span className="os-num text-[17px]">{number.value}</span>
          </button>
        )
      })}
    </div>
  )
}

// The charted numbers, a chart each on its own scale, stacked on the same
// points; one hover line runs through them all, each naming its own numbers.
// Each is headed by its name and change, its total being in the numbers line.
function ChartStack({ numbers }: { numbers: NumberView[] }) {
  const [hover, setHover] = useState<number | null>(null)
  const charted = numbers.filter((number) => number.on && number.chart)
  const height = charted.length > 1 ? "h-[180px]" : ""
  return (
    <div className="os-stack gap-6" onMouseLeave={() => setHover(null)}>
      {charted.map((number) => (
        <section key={number.key} aria-label={number.label}>
          <p className="os-label flex flex-wrap items-baseline gap-x-2">
            <span>{number.label}</span>
            {number.change.words && (
              <span className="text-xs">
                {number.change.arrow && <span className={number.change.up ? "text-up" : "text-down"} aria-label={number.change.up ? "Up" : "Down"}>{number.change.arrow} </span>}
                {number.change.words}
              </span>
            )}
          </p>
          {number.chart && <div className="mt-2"><LineChart chart={number.chart} height={height} shared={charted.length > 1 ? hover : undefined} onHover={setHover} /></div>}
        </section>
      ))}
    </div>
  )
}

// Your projects, under the dashboard's chart: each with Edit up front,
// whether the chart draws it, whether the builder's page shows it (a form,
// as the page reloads without it), and its value in the window for each
// number. On a phone each row stacks, each control under its label.
function ProjectsTableView({ view, table, chart, range }: { view: ProgressView; table: ProjectsTable; chart: (repo: string) => Target; range: ProgressRange | null }) {
  if (table.rows.length === 0) {
    return <div className="mt-6" id="activity-lines"><p className="os-sm os-ink2">No repo has commits here yet. Your public repos appear once the first sync is done.</p></div>
  }
  return (
    <div className="mt-6" id="activity-lines">
      <table className="w-full table-fixed border-collapse text-sm max-sm:block">
        <caption className="sr-only">Your projects: what this chart and your page show of each</caption>
        <thead className="max-sm:hidden">
          <tr className="text-xs text-ink-3">
            <th scope="col" className="py-2 text-left font-bold">Your projects</th>
            <th scope="col" className="w-24 py-2 text-right font-bold">On the chart</th>
            <th scope="col" className="w-24 py-2 text-right font-bold">Your page</th>
            {table.columns.map((column) => <th key={column.key} scope="col" className="w-28 py-2 text-right font-bold">{column.label}</th>)}
          </tr>
        </thead>
        <tbody className="max-sm:block">
          {table.rows.map((row) => <ProjectsRowView key={row.repo} row={row} table={table} chart={chart} range={range} />)}
        </tbody>
      </table>
      <p className="os-note mt-2">Values are the {view.words}. On the chart picks what it draws; Your page, what visitors see.</p>
    </div>
  )
}

function ProjectsRowView({ row, table, chart, range }: { row: ProjectsRow; table: ProjectsTable; chart: (repo: string) => Target; range: ProgressRange | null }) {
  const off = row.page !== null && !row.page.on
  const target = chart(row.repo)
  return (
    <tr className="border-t border-line max-sm:grid max-sm:grid-cols-4 max-sm:gap-x-2 max-sm:gap-y-2.5 max-sm:py-3" data-line-row={row.repo}>
      <th scope="row" className="py-2.5 text-left font-bold max-sm:col-span-4 max-sm:py-0">
        <span className="flex min-w-0 items-center gap-2.5">
          <span className={`os-dot ${projectClass(row.rank)} shrink-0 bg-(--project) ${off || row.chart === false ? "opacity-40" : ""}`} />
          <span className={`truncate ${off ? "text-ink-3" : ""}`}>{row.name}</span>
          {row.edit && <a href={row.edit} className="os-btn2 sm shrink-0" aria-label={`Edit ${row.name}`}>Edit</a>}
        </span>
      </th>
      <td className="py-2.5 text-right max-sm:py-0 max-sm:text-left">
        <span className="os-xs os-muted mb-1 block sm:hidden">On the chart</span>
        {row.chart !== null && (
          <button type="button" role="switch" aria-checked={row.chart} aria-label={`Draw ${row.name} on the chart`} className="os-switch align-middle"
                  onClick={target.go} onPointerEnter={target.warm} onFocus={target.warm} />
        )}
      </td>
      <td className="py-2.5 text-right max-sm:py-0 max-sm:text-left">
        <span className="os-xs os-muted mb-1 block sm:hidden">Your page</span>
        {row.page && <PageSwitch name={row.name} page={row.page} range={range} />}
      </td>
      {table.columns.map((column) => {
        const value = row.values[column.key]
        return (
          <td key={column.key} className="py-2.5 text-right max-sm:py-0 max-sm:text-left">
            <span className="os-xs os-muted mb-1 block sm:hidden">{column.label}</span>
            {value ? <span className="os-num tabular-nums">{value}</span>
              : column.key === "visits" && row.setup ? (
                <a href={row.setup} aria-label={`Set up ${row.name}'s site visits`}
                   className="inline-flex h-[22px] items-center rounded-full border border-line px-2.5 text-[11px] font-bold text-ink-2 hover:border-accent hover:text-accent-ink">Set up</a>
              ) : <span className="os-xs os-muted">–</span>}
          </td>
        )
      })}
    </tr>
  )
}

// GithubReposController switches it and sends the dashboard back.
function PageSwitch({ name, page, range }: { name: string; page: { on: boolean; path: string }; range: ProgressRange | null }) {
  return (
    <form method="post" action={page.path} className="inline-flex" data-turbo="false">
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" value={csrfToken()} />
      <input type="hidden" name="included" value={String(!page.on)} />
      {range && <input type="hidden" name="range" value={range} />}
      <button type="submit" role="switch" aria-checked={page.on} aria-label={`Show ${name} on your page`} className="os-switch" />
    </form>
  )
}

function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""
}

function Arrow({ view }: { view: ProgressView }) {
  const { arrow, up } = view.change
  if (!arrow) return null
  return <span className={up ? "text-up" : "text-down"} aria-label={up ? "Up" : "Down"}>{arrow}</span>
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
function ProjectSwitches({ view, to }: { view: ProgressView; to: (selected: string[]) => Target }) {
  return (
    <Switches label="Projects" target={(repo) => to(toggledProjects(view, repo))} all={view.filtered ? to([]) : null}
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
