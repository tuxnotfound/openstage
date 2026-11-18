import type { PageLists, Ranked, SiteLists } from "../types"

// The lists under an analytics tab's chart, a panel each, as many to a row
// as fit. A ranked list: each row's name on a bar as long as its share of
// the first, with the dot of its project or page where it carries one (its
// name for a screen reader, and on hover), then its count; Other last, with
// no bar. Its unit sits at the top right. A long name is cut, whole on
// hover.

const PANEL = "os-panel p-[clamp(16px,1.7vw,24px)]"
const GRID = "grid grid-cols-[repeat(auto-fit,minmax(min(100%,290px),1fr))] gap-4"

export function RankedList({ id, title, unit, ranked }: { id: string; title: string; unit: string; ranked: Ranked }) {
  return (
    <section className={PANEL} aria-labelledby={id}>
      <Head id={id} title={title} unit={unit} />
      {ranked.empty ? <p className="os-note mt-3">{ranked.empty}</p> : (
        <ul className="mt-3 flex flex-col gap-[3px]">
          {ranked.rows.map((row, index) => (
            <li key={`${index} ${row.label}`} className="flex min-h-8 items-center gap-3">
              <span className="relative flex min-h-8 min-w-0 flex-auto items-center">
                {!row.other && <span className="absolute inset-y-0 left-0 rounded-lg bg-bar" style={{ width: `${row.width}%` }} aria-hidden="true" />}
                <span className={`relative flex min-w-0 items-center gap-2 px-2.5 text-sm ${row.other ? "font-medium text-ink-3" : "font-semibold"}`}>
                  {row.colorClass && <span className={`os-dot ${row.colorClass} bg-(--project)`} title={row.of ?? undefined} aria-hidden="true" />}
                  <span className="truncate" title={row.label}>{row.label}</span>
                  {row.of && <span className="sr-only">, {row.of}</span>}
                </span>
              </span>
              <Count count={row.count} muted={row.other} />
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

function Head({ id, title, unit }: { id: string; title: string; unit: string }) {
  return (
    <div className="flex items-baseline justify-between gap-3">
      <h2 id={id} className="os-h3">{title}</h2>
      <span className="text-xs font-bold whitespace-nowrap text-ink-3">{unit}</span>
    </div>
  )
}

function Count({ count, muted = false }: { count: string; muted?: boolean }) {
  return (
    <span className={`min-w-12 flex-none text-right font-display text-[15px] font-semibold tracking-[-.02em] tabular-nums ${muted ? "text-ink-3" : ""}`}>{count}</span>
  )
}

// Site visits' lists: pages by page views, then sources, ref tags and
// countries by visitors; with none, one line says why, and while none of
// the projects in view counts site visits, links to set one up.
export function SiteListsView({ site }: { site: SiteLists }) {
  if (site.empty) {
    return (
      <div className={PANEL}>
        <p className="os-note">{site.empty} {site.setup && <a className="os-link text-[13px]" href={site.setup.path}>{site.setup.text}</a>}</p>
      </div>
    )
  }
  return (
    <div className={GRID}>
      <RankedList id="site-pages" title="Pages" unit="Views" ranked={site.pages} />
      <RankedList id="site-sources" title="Sources" unit="Visitors" ranked={site.sources} />
      <RankedList id="site-refs" title="Ref tags" unit="Visitors" ranked={site.refs} />
      <RankedList id="site-countries" title="Countries" unit="Visitors" ranked={site.countries} />
    </div>
  )
}

// Openstage views' lists: sources and countries by views, the links
// followed, and where the badge and the embed were shown.
export function PageListsView({ pages }: { pages: PageLists }) {
  return (
    <div className={GRID}>
      <RankedList id="page-sources" title="Sources" unit="Views" ranked={pages.sources} />
      <RankedList id="page-countries" title="Countries" unit="Views" ranked={pages.countries} />
      <RankedList id="page-links" title="Links followed" unit="Clicks out" ranked={pages.links} />
      <section className={PANEL} aria-labelledby="page-badges">
        <Head id="page-badges" title="Badge and embed" unit="Times shown" />
        <ul className="mt-2.5 flex flex-col">
          {pages.badges.map((badge) => (
            <li key={badge.label} className="flex items-center gap-3 border-t border-line py-2.5 text-sm first:border-t-0">
              <span className="min-w-0 flex-auto truncate font-semibold">{badge.label}</span>
              <span className="flex-none text-[13px] whitespace-nowrap text-ink-3">{badge.sites}</span>
              <Count count={badge.count} />
            </li>
          ))}
        </ul>
      </section>
    </div>
  )
}
