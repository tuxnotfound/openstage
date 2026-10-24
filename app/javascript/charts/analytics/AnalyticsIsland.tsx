import type { ReactNode } from "react"
import LineChart, { projectClass } from "../LineChart"
import { useView } from "../useView"
import type { AnalyticsChange, AnalyticsRange, AnalyticsView, Metric } from "../types"

// The Pro analytics page: the window, the pages and the number charted switch
// here, each view asked of Api::AnalyticsController and shown in place; the
// page's URL follows.

export type AnalyticsProps = {
  initial: AnalyticsView
  // Api::AnalyticsController's path.
  endpoint: string
}

const RANGES: [AnalyticsRange, string][] = [["7d", "7 days"], ["30d", "30 days"], ["90d", "90 days"]]
const DEFAULT_RANGE: AnalyticsRange = "30d"
const DEFAULT_METRIC: Metric = "visitors"

type Target = { go: () => void; warm: () => void }

export default function AnalyticsIsland({ initial, endpoint }: AnalyticsProps) {
  const { view, busy, failed, show, retry, prefetch } = useView(initial, apiUrl(endpoint, initial.range, initial.metric, initial.selected))

  function to(next: { range?: AnalyticsRange; metric?: Metric; selected?: string[] }): Target {
    const range = next.range ?? view.range
    const metric = next.metric ?? view.metric
    const selected = next.selected ?? view.selected
    const page = new URLSearchParams()
    if (range !== DEFAULT_RANGE) page.set("range", range)
    if (metric !== DEFAULT_METRIC) page.set("metric", metric)
    selected.forEach((key) => page.append("pages[]", key))
    const query = page.toString()
    const api = apiUrl(endpoint, range, metric, selected)
    return { go: () => show(api, `${window.location.pathname}${query ? `?${query}` : ""}`), warm: () => prefetch(api) }
  }

  // With every page in view, switching one leaves the others; none left, or
  // every one, means all of them.
  function toggled(key: string): string[] {
    const keys = view.pages.filter((page) => page.on).map((page) => page.key)
    const next = keys.includes(key) ? keys.filter((each) => each !== key) : [...keys, key]
    return next.length === 0 || next.length === view.pages.length ? [] : view.pages.map((page) => page.key).filter((each) => next.includes(each))
  }

  return (
    <div className="os-stack">
      <div className="os-between">
        <div className="flex items-center gap-2.5">
          <h1 className="os-h2 text-[30px]">Analytics</h1>
          <span className="os-tag pro">✦ Pro</span>
        </div>
        <div className="os-pills" role="group" aria-label="Time range">
          {RANGES.map(([range, label]) => <Control key={range} target={to({ range })} className="os-pill" pressed={range === view.range}>{label}</Control>)}
        </div>
      </div>

      <section className={`os-panel transition-opacity ${busy ? "opacity-60" : ""}`} aria-label="Numbers" aria-busy={busy}>
        <div role="group" aria-label="Pages" className="flex flex-wrap gap-2">
          <Control target={to({ selected: [] })} className={`os-chip ${view.everything ? "" : "text-ink"}`} pressed={view.everything}>All pages</Control>
          {view.pages.map((page) => (
            <Control key={page.key} target={to({ selected: toggled(page.key) })} pressed={page.on}
                     className={`os-chip ${projectClass(page.rank)} ${page.on ? "border-(--project) bg-(--project) text-(--on-project)" : "border-dashed"}`}>
              <span className={`os-dot ${page.on ? "bg-current opacity-60" : "bg-line"}`} />{page.name}
            </Control>
          ))}
        </div>

        <div className="os-pills mt-5.5 flex-wrap" role="group" aria-label="Numbers">
          {view.tabs.map((tab) => (
            <Control key={tab.metric} target={to({ metric: tab.metric })} pressed={tab.metric === view.metric} className="os-pill h-auto flex-col items-start px-[18px] py-2">
              <span className="block text-xs">{tab.label}</span>
              <span><span className="os-num text-[22px]">{tab.value}</span>{tab.change.arrow && <> <span className="text-xs font-bold">{tab.change.arrow} {tab.change.text}</span></>}</span>
            </Control>
          ))}
        </div>

        <div className="mt-5.5 flex flex-wrap items-start gap-x-9 gap-y-6">
          <div className="min-w-0 flex-[999_1_520px]">
            <p className="os-label">{view.label} · {view.scope}, {view.words}</p>
            <div className="mt-0.5 flex flex-wrap items-baseline gap-x-[22px] gap-y-1.5">
              <span className="os-num os-big">{view.total}</span>
              <span className="text-lg font-semibold text-ink-2">
                {view.change.arrow
                  ? <><Arrow change={view.change} /> {view.change.text} vs the {view.windowLabel} before</>
                  : `none in the ${view.windowLabel} before`}
              </span>
            </div>
            <div className="mt-5"><LineChart chart={view.chart} height="h-[260px]" /></div>
          </div>
          <Visits view={view} />
        </div>
        {failed && (
          <p role="status" className="os-note mt-3">
            That view did not load. <button type="button" className="os-link text-[13px]" onClick={retry}>Try again</button>
          </p>
        )}
      </section>

      <ByPage view={view} />

      <div className="os-grid2 items-start">
        <section className="os-panel" aria-labelledby="links-followed">
          <h2 id="links-followed" className="os-h3">Links they followed</h2>
          <p className="os-xs os-muted mt-1 mb-2">Clicks from your pages, {view.words}.</p>
          {view.links.map((link) => (
            <div key={`${link.page}-${link.title}`} className="os-row os-between gap-3 py-2.5">
              <span className="min-w-0"><span className="block text-[15px] font-semibold">{link.title}</span><span className="os-xs os-muted">{link.page}</span></span>
              <span className="os-num font-bold">{link.count}</span>
            </div>
          ))}
          {view.links.length === 0 && <p className="os-note">No clicks out in the {view.words}.</p>}
        </section>

        <section className="os-panel" aria-labelledby="badge-embed">
          <h2 id="badge-embed" className="os-h3">README badge and embed</h2>
          <p className="os-xs os-muted mt-1 mb-2">Times they were shown on other sites, {view.words}.</p>
          {view.badges.map((badge) => (
            <div key={badge.label} className="os-row os-between py-2.5">
              <span className="os-sm font-semibold">{badge.label}</span>
              <span className="os-sm"><span className="os-num font-bold">{badge.count}</span> <span className="os-muted">· {badge.sites}</span></span>
            </div>
          ))}
        </section>
      </div>
    </div>
  )
}

function apiUrl(endpoint: string, range: AnalyticsRange, metric: Metric, selected: string[]): string {
  const query = new URLSearchParams({ range, metric })
  selected.forEach((key) => query.append("pages[]", key))
  return `${endpoint}?${query.toString()}`
}

// A button that asks for its view on click and warms it when the pointer or
// focus reaches it.
function Control({ target, pressed, className, children }: { target: Target; pressed: boolean; className: string; children: ReactNode }) {
  return (
    <button type="button" className={className} aria-pressed={pressed} onClick={target.go} onPointerEnter={target.warm} onFocus={target.warm}>
      {children}
    </button>
  )
}

function Arrow({ change }: { change: AnalyticsChange }) {
  return <span className={tone(change.up)} aria-label={change.up === null ? "No change" : change.up ? "Up" : "Down"}>{change.arrow}</span>
}

function tone(up: boolean | null): string {
  return up === null ? "" : up ? "text-up" : "text-down"
}

function Visits({ view }: { view: AnalyticsView }) {
  return (
    <div className="min-w-0 flex-[1_1_280px]">
      <h2 className="os-label">Where visitors came from</h2>
      {view.sources.length === 0 && <p className="os-note mt-1">No visits in the {view.words}.</p>}
      {view.sources.map((source) => (
        <div key={source.label} className="os-row py-2">
          <div className="os-between"><span className="os-sm font-semibold">{source.label}</span><span className="os-sm os-num font-bold">{source.count}</span></div>
          <div className="mt-1.5 h-1 rounded-sm bg-accent" style={{ width: `${source.width}%` }} aria-hidden="true" />
        </div>
      ))}
      {view.countries.length > 0 && (
        <>
          <h2 className="os-label mt-4.5">Countries</h2>
          {view.countries.map((country) => (
            <div key={country.label} className="os-row os-between py-2"><span className="os-sm">{country.label}</span><span className="os-sm os-num font-bold">{country.count}</span></div>
          ))}
        </>
      )}
    </div>
  )
}

function ByPage({ view }: { view: AnalyticsView }) {
  return (
    <section className="os-panel" aria-labelledby="by-page">
      <div className="os-between">
        <h2 id="by-page" className="os-h2">By page</h2>
        <span className="os-xs os-muted">Last {view.windowLabel}, against the {view.windowLabel} before</span>
      </div>
      <div className="mt-2.5 overflow-x-auto">
        <table className="w-full min-w-[640px] border-collapse text-sm">
          <thead>
            <tr className="text-right text-xs text-ink-3">
              <th scope="col" className="py-2 text-left font-bold">Page</th>
              {view.tabs.map((tab) => <th key={tab.metric} scope="col" className="py-2 font-bold">{tab.label}</th>)}
              <th scope="col" className="py-2 font-bold">Visitors, change</th>
            </tr>
          </thead>
          <tbody>
            {view.rows.map((row) => (
              <tr key={row.key} className="border-t border-line text-right" data-page-row={row.key}>
                <th scope="row" className="py-2.5 text-left font-bold">
                  <span className="inline-flex items-center gap-2"><span className={`os-dot ${projectClass(row.rank)} bg-(--project)`} />{row.name}</span>
                </th>
                {row.values.map((value, i) => <td key={view.tabs[i]?.metric ?? i} className="os-num py-2.5">{value}</td>)}
                <td className={`py-2.5 font-bold ${tone(row.change.up)}`}>{row.change.arrow ? `${row.change.arrow} ${row.change.text}` : "–"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="os-note border-t border-line pt-2.5">A visitor is one browser on one day. New followers confirmed by email, for your page or one project. Clicks out: a project's Visit and View on GitHub buttons, and the links in your entries, counted on the entry's project.</p>
    </section>
  )
}
