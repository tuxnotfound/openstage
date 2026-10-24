import { useState, type ReactNode } from "react"
import { createPortal } from "react-dom"
import LineChart, { projectClass } from "../LineChart"
import { useView } from "../useView"
import type { ProgressRange, ProgressView, ShippedItem } from "../types"

// The commit chart and what it counts, on a builder's page, a project's page
// and the dashboard. A click asks Api::ProgressController for that view and
// shows it in place; the page's URL follows, so the view stays shareable.

export type ProgressProps = {
  initial: ProgressView
  // Api::ProgressController's path for this builder.
  endpoint: string
  mode: "page" | "project" | "dashboard"
  defaultRange: ProgressRange
  // The What shipped section to keep in step, by element id.
  shippedTarget?: string
}

const RANGES: [ProgressRange, string][] = [["30d", "30 days"], ["90d", "90 days"], ["12m", "12 months"], ["all", "All time"]]
const SHOWN = 8

type Target = { go: () => void; warm: () => void }

export default function ProgressIsland({ initial, endpoint, mode, defaultRange, shippedTarget }: ProgressProps) {
  const { view, busy, failed, show, retry, prefetch } = useView(initial, apiUrl(endpoint, initial.range, initial.selected))

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
          <Filters view={view} pills={pills} to={to} />
          <div className="mt-[22px]">{chart}</div>
        </>
      )}
      {mode === "project" && (
        <>
          <div className="os-between mt-7.5 items-end">
            <div>
              <p className="os-label">Commits · {view.words}</p>
              <Headcount view={view} />
            </div>
            {pills}
          </div>
          <div className="mt-[22px]">{chart}</div>
        </>
      )}
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
  const query = new URLSearchParams({ range })
  selected.forEach((repo) => query.append("repo[]", repo))
  return `${endpoint}?${query.toString()}`
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

// Project chips switch a project in or out of view: with every project in
// view, switching one leaves the others; none left, or all, means all.
function Filters({ view, pills, to }: { view: ProgressView; pills: ReactNode; to: (range: ProgressRange, selected: string[]) => Target }) {
  const all = view.projects.map((project) => project.repo)
  const toggled = (repo: string) => {
    const picked = view.filtered ? view.selected : all
    const next = picked.includes(repo) ? picked.filter((each) => each !== repo) : [...picked, repo]
    return next.length === 0 || next.length === all.length ? [] : all.filter((each) => next.includes(each))
  }
  const everything = to(view.range, [])

  return (
    <div className="os-between mt-6">
      {view.projects.length > 1 && (
        <div role="group" aria-label="Projects" className="flex flex-wrap gap-2">
          <button type="button" className={`os-chip ${view.filtered ? "text-ink" : ""}`} aria-pressed={!view.filtered}
                  onClick={everything.go} onPointerEnter={everything.warm} onFocus={everything.warm}>All projects</button>
          {view.projects.map((project) => {
            const target = to(view.range, toggled(project.repo))
            return (
              <button key={project.repo} type="button" aria-pressed={project.on} onClick={target.go} onPointerEnter={target.warm} onFocus={target.warm}
                      className={`os-chip ${projectClass(project.rank)} ${project.on ? "border-(--project) bg-(--project) text-(--on-project)" : "border-dashed"}`}>
                <span className={`os-dot ${project.on ? "bg-current opacity-60" : "bg-line"}`} />{project.name}
              </button>
            )
          })}
        </div>
      )}
      <div className="flex flex-wrap items-center gap-2.5">{pills}</div>
    </div>
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
