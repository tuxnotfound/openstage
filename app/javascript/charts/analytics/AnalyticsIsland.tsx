import { useState } from "react"
import LineChart, { projectClass } from "../LineChart"
import { DEFAULT_RANGE, METRIC_LABELS, METRICS, RANGES, Report, type AnalyticsData, type Metric, type Page, type Range } from "./report"

// The Pro analytics page: the window, the pages and the number picked switch
// here, from the daily rows the server sent, and the URL follows in place.

export type AnalyticsProps = { data: AnalyticsData }

const number = (value: number) => value.toLocaleString("en-US")

export default function AnalyticsIsland({ data }: AnalyticsProps) {
  const [range, setRange] = useState<Range>(data.range)
  const [metric, setMetric] = useState<Metric>(data.metric)
  const [picked, setPicked] = useState<string[]>(data.selected)
  const report = new Report(data, range, metric, picked)

  function update(next: { range?: Range; metric?: Metric; picked?: string[] }) {
    const nextRange = next.range ?? range
    const nextMetric = next.metric ?? metric
    const nextPicked = next.picked ?? picked
    setRange(nextRange)
    setMetric(nextMetric)
    setPicked(nextPicked)
    const params = new URLSearchParams()
    if (nextRange !== DEFAULT_RANGE) params.set("range", nextRange)
    if (nextMetric !== METRICS[0]) params.set("metric", nextMetric)
    nextPicked.forEach((key) => params.append("pages[]", key))
    const query = params.toString()
    window.history.replaceState(window.history.state, "", `${window.location.pathname}${query ? `?${query}` : ""}`)
  }

  // With every page in view, switching one leaves the others; none left, or
  // every one, means all of them.
  function toggle(page: Page) {
    const keys = report.selected.map((each) => each.key)
    const next = keys.includes(page.key) ? keys.filter((key) => key !== page.key) : [...keys, page.key]
    update({ picked: next.length === 0 || next.length === data.pages.length ? [] : next })
  }

  const label = METRIC_LABELS[metric]
  const [arrow, change, up] = changeOf(report.change(metric))

  return (
    <div className="os-stack">
      <div className="os-between">
        <div className="flex items-center gap-2.5">
          <h1 className="os-h2 text-[30px]">Analytics</h1>
          <span className="os-tag pro">✦ Pro</span>
        </div>
        <div className="os-pills" role="group" aria-label="Time range">
          {RANGES.map((each) => (
            <button key={each} type="button" className="os-pill" aria-pressed={each === range} onClick={() => update({ range: each })}>
              {each === "90d" ? "90 days" : `${each.replace("d", "")} days`}
            </button>
          ))}
        </div>
      </div>

      <section className="os-panel" aria-label="Numbers">
        <div role="group" aria-label="Pages" className="flex flex-wrap gap-2">
          <button type="button" className={`os-chip ${report.everything ? "" : "text-ink"}`} aria-pressed={report.everything} onClick={() => update({ picked: [] })}>All pages</button>
          {data.pages.map((page) => {
            const on = report.selected.includes(page)
            return (
              <button key={page.key} type="button" aria-pressed={on} onClick={() => toggle(page)}
                      className={`os-chip ${projectClass(page.rank)} ${on ? "border-(--project) bg-(--project) text-(--on-project)" : "border-dashed"}`}>
                <span className={`os-dot ${on ? "bg-current opacity-60" : "bg-line"}`} />{page.name}
              </button>
            )
          })}
        </div>

        <div className="os-pills mt-5.5 flex-wrap" role="group" aria-label="Numbers">
          {METRICS.map((each) => {
            const [tabArrow, tabChange] = changeOf(report.change(each))
            return (
              <button key={each} type="button" className="os-pill h-auto flex-col items-start px-[18px] py-2" aria-pressed={each === metric} onClick={() => update({ metric: each })}>
                <span className="block text-xs">{METRIC_LABELS[each]}</span>
                <span><span className="os-num text-[22px]">{number(report.total(each))}</span>{tabArrow && <> <span className="text-xs font-bold">{tabArrow} {tabChange}</span></>}</span>
              </button>
            )
          })}
        </div>

        <div className="mt-5.5 flex flex-wrap items-start gap-x-9 gap-y-6">
          <div className="min-w-0 flex-[999_1_520px]">
            <p className="os-label">{label} · {report.everything ? "all pages" : sentence(report.selected.map((page) => page.name))}, {report.words}</p>
            <div className="mt-0.5 flex flex-wrap items-baseline gap-x-[22px] gap-y-1.5">
              <span className="os-num os-big">{number(report.total(metric))}</span>
              <span className="text-lg font-semibold text-ink-2">
                {arrow ? (
                  <><span className={tone(up)} aria-label={up === null ? "No change" : up ? "Up" : "Down"}>{arrow}</span> {change} vs the {report.label} before</>
                ) : `none in the ${report.label} before`}
              </span>
            </div>
            <div className="mt-5">
              <LineChart lines={report.lines} titles={report.titles()} axis={report.axis()} height="h-[260px]" none="Nothing"
                         ariaLabel={`${label} per ${report.unit} by page, ${report.words}`} note={`${label} per ${report.unit}, one line per page.`}
                         emptyNote={`No ${label.toLowerCase()} in the ${report.words}.`} />
            </div>
          </div>
          <Visits report={report} />
        </div>
      </section>

      <ByPage report={report} />

      <div className="os-grid2 items-start">
        <section className="os-panel" aria-labelledby="links-followed">
          <h2 id="links-followed" className="os-h3">Links they followed</h2>
          <p className="os-xs os-muted mt-1 mb-2">Clicks from your pages, {report.words}.</p>
          {report.links.map((link) => (
            <div key={`${link.page.key}-${link.title}`} className="os-row os-between gap-3 py-2.5">
              <span className="min-w-0"><span className="block text-[15px] font-semibold">{link.title}</span><span className="os-xs os-muted">{link.page.name}</span></span>
              <span className="os-num font-bold">{number(link.count)}</span>
            </div>
          ))}
          {report.links.length === 0 && <p className="os-note">No clicks out in the {report.words}.</p>}
        </section>

        <section className="os-panel" aria-labelledby="badge-embed">
          <h2 id="badge-embed" className="os-h3">README badge and embed</h2>
          <p className="os-xs os-muted mt-1 mb-2">Times they were shown on other sites, {report.words}.</p>
          {report.badges.map(([kind, count, sites]) => (
            <div key={kind} className="os-row os-between py-2.5">
              <span className="os-sm font-semibold">{kind === "badge" ? "README badge" : "Embed widget"}</span>
              <span className="os-sm"><span className="os-num font-bold">{number(count)}</span> <span className="os-muted">· {sites} {sites === 1 ? "site" : "sites"}</span></span>
            </div>
          ))}
        </section>
      </div>
    </div>
  )
}

function Visits({ report }: { report: Report }) {
  const sources = report.sources
  const most = sources[0]?.[1] ?? 1
  return (
    <div className="min-w-0 flex-[1_1_280px]">
      <h2 className="os-label">Where visitors came from</h2>
      {sources.length === 0 && <p className="os-note mt-1">No visits in the {report.words}.</p>}
      {sources.map(([source, count]) => (
        <div key={source} className="os-row py-2">
          <div className="os-between"><span className="os-sm font-semibold">{source}</span><span className="os-sm os-num font-bold">{number(count)}</span></div>
          <div className="mt-1.5 h-1 rounded-sm bg-accent" style={{ width: `${Math.round((100 * count) / most)}%` }} aria-hidden="true" />
        </div>
      ))}
      {report.countries.length > 0 && (
        <>
          <h2 className="os-label mt-4.5">Countries</h2>
          {report.countries.map(([country, count]) => (
            <div key={country} className="os-row os-between py-2"><span className="os-sm">{country}</span><span className="os-sm os-num font-bold">{number(count)}</span></div>
          ))}
        </>
      )}
    </div>
  )
}

function ByPage({ report }: { report: Report }) {
  const rows = [...report.selected].sort((a, b) => report.total("visitors", [b]) - report.total("visitors", [a]))
  return (
    <section className="os-panel" aria-labelledby="by-page">
      <div className="os-between">
        <h2 id="by-page" className="os-h2">By page</h2>
        <span className="os-xs os-muted">Last {report.label}, against the {report.label} before</span>
      </div>
      <div className="mt-2.5 overflow-x-auto">
        <table className="w-full min-w-[640px] border-collapse text-sm">
          <thead>
            <tr className="text-right text-xs text-ink-3">
              <th scope="col" className="py-2 text-left font-bold">Page</th>
              {METRICS.map((each) => <th key={each} scope="col" className="py-2 font-bold">{METRIC_LABELS[each]}</th>)}
              <th scope="col" className="py-2 font-bold">Visitors, change</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((page) => {
              const [arrow, change, up] = changeOf(report.change("visitors", [page]))
              return (
                <tr key={page.key} className="border-t border-line text-right" data-page-row={page.key}>
                  <th scope="row" className="py-2.5 text-left font-bold">
                    <span className="inline-flex items-center gap-2"><span className={`os-dot ${projectClass(page.rank)} bg-(--project)`} />{page.name}</span>
                  </th>
                  {METRICS.map((each) => {
                    const value = report.total(each, [page])
                    return <td key={each} className="os-num py-2.5">{value > 0 ? number(value) : "–"}</td>
                  })}
                  <td className={`py-2.5 font-bold ${tone(up)}`}>{arrow ? `${arrow} ${change}` : "–"}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
      <p className="os-note border-t border-line pt-2.5">A visitor is one browser on one day. New followers confirmed by email, for your page or one project. Clicks out: a project's Visit and View on GitHub buttons, and the links in your entries, counted on the entry's project.</p>
    </section>
  )
}

// ["▲", "22%", true], ["±", "0%", null], or nulls with nothing to compare with.
function changeOf(change: number | null): [string | null, string | null, boolean | null] {
  if (change === null) return [null, null, null]
  if (change === 0) return ["±", "0%", null]
  return [change < 0 ? "▼" : "▲", `${Math.abs(change)}%`, change > 0]
}

function tone(up: boolean | null): string {
  return up === null ? "" : up ? "text-up" : "text-down"
}

// "app", "app and lib", "app, lib, and site", as Rails' to_sentence.
function sentence(names: string[]): string {
  if (names.length <= 2) return names.join(" and ")
  return `${names.slice(0, -1).join(", ")}, and ${names[names.length - 1]}`
}
