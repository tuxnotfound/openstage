import type { AnalyticsView, WebsitesView } from "../types"
import type { PanelSet } from "./panels"

// Under the chart filter, for its window and its pages, as analytics/panels
// renders them: the panels of the builder's websites, or of their pages on
// Openstage, as the switch above them picks, with a line saying what they
// count and where. Both sets came with the view, so the switch shows the
// other at once (flip).

const SETS: { key: PanelSet; label: string; line: string }[] = [
  { key: "websites", label: "On your websites", line: "Visitors and page views on your websites, counted by Openstage's script." },
  { key: "openstage", label: "On Openstage", line: "Views and clicks out on your stage and your project pages, and where your badge and embed were shown." },
]

type Props = { view: AnalyticsView; panels: PanelSet; flip: (panels: PanelSet) => void }

export default function AnalyticsPanels({ view, panels, flip }: Props) {
  return (
    <div className="os-stack">
      <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
        <div className="os-pills" role="group" aria-label="Panels">
          {SETS.map((set) => (
            <button key={set.key} type="button" className="os-pill" aria-pressed={set.key === panels} onClick={() => flip(set.key)}>{set.label}</button>
          ))}
        </div>
        <p className="os-xs os-muted">{SETS.find((set) => set.key === panels)?.line}</p>
      </div>
      {panels === "websites" ? <WebsitePanels site={view.websites} words={view.words} quiet={view.quiet} /> : <OpenstagePanels view={view} />}
    </div>
  )
}

// As analytics/websites: where visitors came from and their countries, their
// ref tags and the busiest pages, each page with its project while pages of
// several count, each list with Other last, what it leaves out; with none of
// them, one line says why. One path can show twice, once per project.
function WebsitePanels({ site, words, quiet }: { site: WebsitesView; words: string; quiet: string }) {
  if (site.empty) {
    return (
      <div className="os-panel">
        <p className="os-note">{site.empty} {site.setup && <a className="os-link text-[13px]" href={site.setup.path}>{site.setup.text}</a>}</p>
      </div>
    )
  }
  return (
    <div className="grid items-start gap-4 lg:grid-cols-3">
      <section className="os-panel" aria-labelledby="site-sources">
        <h2 id="site-sources" className="os-h3">Where visitors came from</h2>
        <p className="os-xs os-muted mt-1 mb-2">Visitors to your websites, by the site they came from, {words}.</p>
        {site.sources.length === 0 && <p className="os-note">No sources {quiet}.</p>}
        {site.sources.map((source) => (
          <div key={source.label} className="os-row py-2">
            <Count label={source.label} count={source.count} css="font-semibold" />
            <div className="mt-1.5 h-1 rounded-sm bg-accent" style={{ width: `${source.width}%` }} aria-hidden="true" />
          </div>
        ))}
        {site.countries.length > 0 && (
          <>
            <h3 className="os-label mt-4.5">Countries</h3>
            {site.countries.map((country) => <div key={country.label} className="os-row py-2"><Count {...country} /></div>)}
          </>
        )}
      </section>

      <section className="os-panel" aria-labelledby="site-refs">
        <h2 id="site-refs" className="os-h3">Ref tags</h2>
        <p className="os-xs os-muted mt-1 mb-2">Visitors by the ref or utm_source tag in their link, {words}.</p>
        {site.refs.map((ref) => <div key={ref.label} className="os-row py-2"><Count {...ref} /></div>)}
        {site.refs.length === 0 && <p className="os-note">No ref tags {quiet}.</p>}
      </section>

      <section className="os-panel" aria-labelledby="site-pages">
        <h2 id="site-pages" className="os-h3">Top pages</h2>
        <p className="os-xs os-muted mt-1 mb-2">Page views on your websites, by path, {words}.</p>
        {site.pages.map((page) => <div key={`${page.project ?? ""} ${page.label}`} className="os-row py-2"><Count {...page} /></div>)}
        {site.pages.length === 0 && <p className="os-note">No page views {quiet}.</p>}
      </section>
    </div>
  )
}

// As analytics/count: a long host, tag or path wraps rather than pushing the
// page sideways, and a page has its project under it, when the server names
// one.
function Count({ label, count, project, css = "" }: { label: string; count: string; project?: string | null; css?: string }) {
  return (
    <div className="flex items-baseline justify-between gap-3">
      <span className={`os-sm min-w-0 wrap-anywhere ${css}`}>{label}{project && <span className="os-xs os-muted block">{project}</span>}</span>
      <span className="os-sm os-num font-bold">{count}</span>
    </div>
  )
}

// As analytics/openstage: where views of the builder's pages came from, and
// so their countries, the links followed, and where the badge and embed
// showed. Its sources count views, not visitors, so its title says so.
function OpenstagePanels({ view }: { view: AnalyticsView }) {
  return (
    <div className="grid items-start gap-4 lg:grid-cols-3">
      <section className="os-panel" aria-labelledby="visitors-from">
        <h2 id="visitors-from" className="os-h3">Where views came from</h2>
        <p className="os-xs os-muted mt-1 mb-2">Views of your Openstage pages, by the site they came from, {view.words}.</p>
        {view.sources.length === 0 && <p className="os-note">No views {view.quiet}.</p>}
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
        <p className="os-xs os-muted mt-1 mb-2">Clicks from your Openstage pages, {view.words}.</p>
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
