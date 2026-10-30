import CompareChart from "../filter/CompareChart"
import NumberToggles from "../filter/NumberToggles"
import ProjectsTable from "../filter/ProjectsTable"
import WindowPills from "../filter/WindowPills"
import { lineOrder } from "../filter/lines"
import { useFilter } from "../filter/useFilter"
import type { AnalyticsView, ProgressRange } from "../types"

// The Pro analytics page on the chart filter every chart page shares
// (useFilter), as analytics/index renders it: the window beside the title;
// the numbers in their groups, each with its change; the chart; and the
// pages under it in their fixed order, each value with its change. Then
// where visitors came from, the links they followed and the badge and
// embed, for the same window and pages.

export type AnalyticsProps = {
  initial: AnalyticsView
  // Api::AnalyticsController's path.
  endpoint: string
  defaultRange: ProgressRange
}

export default function AnalyticsIsland({ initial, endpoint, defaultRange }: AnalyticsProps) {
  // Analytics' old links named its pages pages[] and its one number metric.
  const filter = useFilter(initial, { endpoint, defaultRange, named: true, dropped: ["pages", "pages[]", "metric"] })
  const { view, busy, failed, lines, focus } = filter

  return (
    <div className="os-stack">
      <div className="os-between">
        <div className="flex items-center gap-2.5">
          <h1 className="os-h2 text-[30px]">Analytics</h1>
          <span className="os-tag pro">✦ Pro</span>
        </div>
        <WindowPills range={view.range} target={filter.window} className="max-md:flex max-md:w-full max-md:justify-between" />
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
          <p className="os-note mt-0 border-t border-line pt-2.5">Commits: yours, public, merges and dependency bumps left out. Site visits: page views on a project's own website, counted by Openstage's script. On Openstage, your stage and your project pages: a visitor is one browser on one day; views count every page load; new followers confirmed by email, for your stage or one project; clicks out are a project's Visit and View on GitHub buttons and the links in your entries. Your own visits and bots are left out.</p>
        </section>

        <Panels view={view} />
      </div>
    </div>
  )
}

function Panels({ view }: { view: AnalyticsView }) {
  return (
    <div className="grid items-start gap-4 lg:grid-cols-3">
      <section className="os-panel" aria-labelledby="visitors-from">
        <h2 id="visitors-from" className="os-h3">Where visitors came from</h2>
        <p className="os-xs os-muted mt-1 mb-2">Views of your Openstage pages, by the site they came from, {view.words}.</p>
        {view.sources.length === 0 && <p className="os-note">No visits {view.quiet}.</p>}
        {view.sources.map((source) => (
          <div key={source.label} className="os-row py-2">
            <div className="os-between"><span className="os-sm font-semibold">{source.label}</span><span className="os-sm os-num font-bold">{source.count}</span></div>
            <div className="mt-1.5 h-1 rounded-sm bg-accent" style={{ width: `${source.width}%` }} aria-hidden="true" />
          </div>
        ))}
        {view.countries.length > 0 && (
          <>
            <h3 className="os-label mt-4.5">Countries</h3>
            {view.countries.map((country) => (
              <div key={country.label} className="os-row os-between py-2"><span className="os-sm">{country.label}</span><span className="os-sm os-num font-bold">{country.count}</span></div>
            ))}
          </>
        )}
      </section>

      <section className="os-panel" aria-labelledby="links-followed">
        <h2 id="links-followed" className="os-h3">Links they followed</h2>
        <p className="os-xs os-muted mt-1 mb-2">Clicks from your pages, {view.words}.</p>
        {view.links.map((link) => (
          <div key={`${link.page}-${link.title}`} className="os-row os-between gap-3 py-2.5">
            <span className="min-w-0"><span className="block text-[15px] font-semibold">{link.title}</span><span className="os-xs os-muted">{link.page}</span></span>
            <span className="os-num font-bold">{link.count}</span>
          </div>
        ))}
        {view.links.length === 0 && <p className="os-note">No clicks out {view.quiet}.</p>}
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
  )
}
