import { useState } from "react"
import CompareChart from "../filter/CompareChart"
import NumberToggles from "../filter/NumberToggles"
import ProjectsTable from "../filter/ProjectsTable"
import WindowPills from "../filter/WindowPills"
import { lineOrder } from "../filter/lines"
import { useFilter } from "../filter/useFilter"
import type { AnalyticsView, ProgressRange } from "../types"
import AnalyticsPanels from "./AnalyticsPanels"
import { PANELS_PARAM, panelsIn, panelsUrl, type PanelSet } from "./panels"

// The Pro analytics page on the chart filter every chart page shares
// (useFilter), as analytics/index renders it: the window beside the title;
// the numbers in their groups, each with its change; the chart; and the
// pages under it in their fixed order, each value with its change. Then the
// panels of the builder's websites or of their pages on Openstage, for the
// same window and pages, as the page's URL names them (panels.ts): a switch
// shows the other set at once and follows the one before in the browser's
// history, as a new window does.

export type AnalyticsProps = {
  initial: AnalyticsView
  // Api::AnalyticsController's path.
  endpoint: string
  defaultRange: ProgressRange
}

export default function AnalyticsIsland({ initial, endpoint, defaultRange }: AnalyticsProps) {
  const [panels, setPanels] = useState(() => panelsIn(window.location.href))
  // Analytics' old links named its pages pages[] and its one number metric.
  const filter = useFilter(initial, {
    endpoint, defaultRange, named: true, dropped: ["pages", "pages[]", "metric"],
    kept: [PANELS_PARAM], restored: () => setPanels(panelsIn(window.location.href)),
  })
  const { view, busy, failed, lines, focus } = filter

  function flip(next: PanelSet) {
    if (next === panels) return
    setPanels(next)
    filter.step(panelsUrl(window.location.href, next))
  }

  return (
    <div className="os-stack">
      <div className="os-between">
        <div className="flex items-center gap-2.5">
          <h1 className="os-h2 text-[30px]">Analytics</h1>
          <span className="os-tag pro">✦ Pro</span>
        </div>
        <WindowPills range={view.range} calendar={view.calendar} target={filter.window} className="max-md:flex max-md:w-full max-md:justify-between" />
      </div>

      <div aria-busy={busy} className={`os-stack transition-opacity ${busy ? "opacity-60" : ""}`}>
        <section className="os-panel" aria-label="Numbers">
          <NumberToggles numbers={view.numbers} lines={lines} indexed={view.chart.indexed} changes groups {...filter.numbers} />
          <p role="status" className="mt-2.5 text-[13px] font-semibold text-ink-2 empty:mt-0">{filter.notice}</p>
          <CompareChart chart={view.chart} numbers={view.numbers} lines={lines} focus={focus} height="h-[260px]" />
          {view.changesNote && <p className="os-xs os-muted mt-5.5">{view.changesNote}</p>}
          {view.table && (
            <ProjectsTable table={view.table} drawn={lineOrder(lines)} lines={lines} indexed={view.chart.indexed} words={view.words}
                           focused={focus?.kind === "project" ? focus.key : null} rows={filter.rows} label="Pages" />
          )}
          {failed && (
            <p role="status" className="os-note mt-3">
              That view did not load. <button type="button" className="os-link text-[13px]" onClick={filter.retry}>Try again</button>
            </p>
          )}
          <p className="os-note mt-0 border-t border-line pt-2.5">Commits: yours, public, merges and dependency bumps left out. On a project's own website, counted by Openstage's script: site visits are page views; a site visitor is one browser on one day. On Openstage, your stage and your project pages: a visitor is one browser on one day; views count every page load; new followers confirmed by email, for your stage or one project; clicks out are a project's Visit and View on GitHub buttons and the links in your entries. Bots are left out, and on Openstage your own visits too.</p>
        </section>

        <AnalyticsPanels view={view} panels={panels} flip={flip} />
      </div>
    </div>
  )
}
