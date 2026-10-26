import { useState, type ReactNode } from "react"
import { createPortal } from "react-dom"
import LineChart, { projectClass } from "../LineChart"
import Switches, { type Target } from "../Switches"
import { useView } from "../useView"
import type { ProjectMetric, ProgressRange, ProgressView, ShippedItem } from "../types"

// The commit chart and what it counts, on a builder's page, a project's page
// and the dashboard. A click asks Api::ProgressController for that view and
// shows it in place; the page's URL follows, so the view stays shareable.

export type ProgressProps = {
  initial: ProgressView
  // Api::ProgressController's path for this builder, with any params of its
  // own (a hidden project's, for its builder).
  endpoint: string
  mode: "page" | "project" | "dashboard"
  // A project's page: the number charted first.
  metric?: ProjectMetric
  defaultRange: ProgressRange
  // The What shipped section to keep in step, by element id.
  shippedTarget?: string
}

const RANGES: [ProgressRange, string][] = [["30d", "30 days"], ["90d", "90 days"], ["12m", "12 months"], ["all", "All time"]]
const SHOWN = 8

export default function ProgressIsland({ initial, endpoint, mode, metric: initialMetric = "commits", defaultRange, shippedTarget }: ProgressProps) {
  const { view, busy, failed, show, retry, prefetch } = useView(initial, apiUrl(endpoint, initial.range, initial.selected))
  const [metric, setMetric] = useState<ProjectMetric>(initialMetric)

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
  const chart = <LineChart chart={view.chart} height={mode === "dashboard" ? "h-[260px]" : ""} legend={mode === "dashboard"} />
  const shipped = shippedTarget ? document.getElementById(shippedTarget) : null

  return (
    <div aria-busy={busy} className={`transition-opacity ${busy ? "opacity-60" : ""}`}>
      {mode === "page" && (
        <>
          <PageHeadline view={view} />
          <div className={`mt-6 grid items-start gap-x-8 gap-y-6 ${view.projects.length > 1 ? "lg:grid-cols-[minmax(0,1fr)_280px]" : ""}`}>
            <div className="min-w-0">
              <div className="flex justify-end">{pills}</div>
              <div className="mt-[22px]">{chart}</div>
            </div>
            {view.projects.length > 1 && <ProjectSwitches view={view} to={to} />}
          </div>
        </>
      )}
      {mode === "project" && <ProjectNumbers view={view} metric={metric} pick={setMetric} pills={pills} chart={chart} />}
      {mode === "dashboard" && (
        <>
          <div className="os-between">
            <h2 id="your-activity" className="os-h2">Your activity</h2>
            {pills}
          </div>
          <div className="mt-3 flex flex-wrap items-baseline gap-x-3.5 gap-y-1">
            <span className="os-num text-[56px] leading-none">{view.commits}</span>
            <span className="os-ink2">commits, {view.words}{view.change.words && <> · <Arrow view={view} /> {view.change.words}</>}</span>
          </div>
          <div className="mt-3.5">{chart}</div>
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

// A project's page: with site visits, a tab per number above the chart
// switches it, and the page's URL keeps the pick.
function ProjectNumbers({ view, metric, pick, pills, chart }: {
  view: ProgressView; metric: ProjectMetric; pick: (metric: ProjectMetric) => void; pills: ReactNode; chart: ReactNode
}) {
  const site = view.site
  const visits = metric === "visits" && site !== null
  const tabs: [ProjectMetric, string, string][] = [["commits", "Commits", String(view.commits)], ["visits", "Site visits", site?.value ?? ""]]

  function choose(next: ProjectMetric) {
    pick(next)
    const url = new URL(window.location.href)
    if (next === "commits") url.searchParams.delete("metric")
    else url.searchParams.set("metric", next)
    window.history.replaceState(window.history.state, "", url)
  }

  return (
    <>
      {site && (
        <div className="os-pills mt-7 flex-wrap" role="group" aria-label="Numbers">
          {tabs.map(([key, label, value]) => (
            <button key={key} type="button" className="os-pill h-auto flex-col items-start px-[18px] py-2" aria-pressed={(key === "visits") === visits}
                    onClick={() => choose(key)}>
              <span className="block text-xs">{label}</span><span className="os-num text-[22px]">{value}</span>
            </button>
          ))}
        </div>
      )}
      <div className={`os-between items-end ${site ? "mt-5.5" : "mt-7.5"}`}>
        <div>
          <p className="os-label">{visits ? "Site visits" : "Commits"} · {view.words}</p>
          {visits && site ? (
            <div className="mt-0.5 flex flex-wrap items-baseline gap-x-[22px] gap-y-1.5">
              <span className="os-num os-big">{site.value}</span>
              <span className="text-lg font-semibold text-ink-2">{site.visitors}</span>
            </div>
          ) : <Headcount view={view} />}
        </div>
        {pills}
      </div>
      <div className="mt-[22px]">{visits && site ? <LineChart chart={site.chart} /> : chart}</div>
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
