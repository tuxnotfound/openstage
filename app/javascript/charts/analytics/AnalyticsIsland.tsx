import type { ReactNode } from "react"
import CompareChart from "../filter/CompareChart"
import ProjectsTable from "../filter/ProjectsTable"
import WindowPills from "../filter/WindowPills"
import { lineOrder } from "../filter/lines"
import { useFilter } from "../filter/useFilter"
import type { AnalyticsView, LockedView, ProgressRange } from "../types"
import AnalyticsTabs from "./AnalyticsTabs"
import CommitPartsView from "./CommitPartsView"
import GoPro from "./GoPro"
import { PageListsView, SiteListsView } from "./RankedList"
import RevenuePartsView from "./RevenuePartsView"
import Tiles from "./Tiles"

// The analytics page, all of it, as analytics/index hands it over: the
// title, with Pro's mark on Pro alone, and the window beside it; the tabs;
// then the tab on the chart filter every chart page shares (useFilter): its
// tiles, the chart, and its table, beside the chart on a tab where both fit
// and under it on Overview, and none on a tab with no row, whose chart says
// why; then the tab's parts: when the builder commits and what's new, on
// Commits, where a mark on the chart leads to its row; the products and
// MRR by week, on MRR; or the lists. The window, the numbers and the rows
// switch in place; a tab is a page of its own. On a tab Free does not open,
// the Go Pro view, with no window.

export type AnalyticsProps = {
  initial: AnalyticsView | LockedView
  // Api::AnalyticsController's path, with the tab's param.
  endpoint: string
  defaultRange: ProgressRange
  // Whether the builder is on Pro, for the mark beside the title.
  pro: boolean
  // What the builder can do while the chart has nothing to draw (chart_step).
  step: { text: string; label: string; href: string } | null
}

const PANEL = "os-panel p-[clamp(16px,1.7vw,24px)]"

export default function AnalyticsIsland(props: AnalyticsProps) {
  const { initial } = props
  return initial.locked ? <Locked view={initial} pro={props.pro} defaultRange={props.defaultRange} /> : <Open {...props} initial={initial} />
}

function Title({ pro, children }: { pro: boolean; children?: ReactNode }) {
  return (
    <div className="os-between">
      <div className="flex items-center gap-2.5">
        <h1 className="os-h2 text-[30px]">Analytics</h1>
        {pro && <span className="os-tag pro">✦ Pro</span>}
      </div>
      {children}
    </div>
  )
}

// The tabs keep the window and the projects the address named.
function Locked({ view, pro, defaultRange }: { view: LockedView; pro: boolean; defaultRange: ProgressRange }) {
  const query = new URL(window.location.href).searchParams
  const projects = query.get("projects")?.split(",").filter(Boolean) ?? []
  return (
    <div className="os-stack">
      <Title pro={pro} />
      <AnalyticsTabs tabs={view.tabs} current={view.tab} range={query.get("range") as ProgressRange | null} projects={projects} defaultRange={defaultRange} />
      <GoPro view={view} />
    </div>
  )
}

function Open({ initial, endpoint, defaultRange, pro, step }: AnalyticsProps & { initial: AnalyticsView }) {
  // Analytics' old links named its pages pages[] and its one number metric.
  const filter = useFilter(initial, { endpoint, defaultRange, named: true, dropped: ["pages", "pages[]", "metric"] })
  const { view, busy, failed, lines, focus } = filter
  const beside = view.tab !== "overview" && view.table !== null

  const chart = (
    <>
      <Tiles tiles={view.tiles} lines={lines} indexed={view.chart.indexed} {...filter.numbers} />
      <p role="status" className="mt-2.5 text-[13px] font-semibold text-ink-2 empty:mt-0">{filter.notice}</p>
      <CompareChart chart={view.chart} lines={lines} focus={focus} lead={view.commits ? "news" : undefined} />
      {step && view.chart.paths.length === 0 && (
        <p className="os-note mt-2" data-chart-step>{step.text} <a className="os-link text-[13px]" href={step.href} data-turbo="false">{step.label}</a></p>
      )}
    </>
  )
  const table = view.table && (
    <ProjectsTable table={view.table} drawn={lineOrder(lines)} lines={lines} indexed={view.chart.indexed} words={view.words}
                   focused={focus?.kind === "project" ? focus.key : null} rows={filter.rows} label={view.rowsLabel} beside={beside} />
  )

  return (
    <div className="os-stack">
      <Title pro={pro}>
        <WindowPills range={view.range} calendar={view.calendar} target={filter.window} className="max-md:flex max-md:w-full max-md:justify-between" />
      </Title>
      <AnalyticsTabs tabs={view.tabs} current={view.tab} range={view.range} projects={view.selected} defaultRange={defaultRange} />

      <div aria-busy={busy} className={`os-stack transition-opacity ${busy ? "opacity-60" : ""}`}>
        <section className={PANEL} aria-label="Numbers">
          {beside ? (
            <div className="flex flex-wrap items-start gap-x-9 gap-y-[22px]">
              <div className="min-w-0 flex-[999_1_600px]">{chart}</div>
              <div className={`min-w-0 ${view.tab === "openstage" ? "flex-[1_1_580px]" : "flex-[1_1_400px]"}`}>{table}</div>
            </div>
          ) : <>{chart}{table}</>}
          {view.changesNote && <p className="os-xs os-muted mt-3.5">{view.changesNote}</p>}
          {failed && (
            <p role="status" className="os-note mt-3">
              That view did not load. <button type="button" className="os-link text-[13px]" onClick={filter.retry}>Try again</button>
            </p>
          )}
        </section>

        {view.commits && <CommitPartsView commits={view.commits} words={view.words} />}
        {view.revenue && <RevenuePartsView revenue={view.revenue} />}
        {view.site && <SiteListsView site={view.site} />}
        {view.pages && <PageListsView pages={view.pages} />}
      </div>
    </div>
  )
}
