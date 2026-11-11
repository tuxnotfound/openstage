import { useEffect, useRef, useState, type FormEvent } from "react"
import { PageSwitch, PinSwitch } from "../filter/ProjectsTable"
import type { ProjectListRow, ProjectListView } from "../types"
import { useView } from "../useView"

// The stage's list of a builder's projects past the cards, as
// profiles/page/_more_projects renders it first: found by name as the
// visitor types, sorted, filtered to the live ones and paged, each view asked
// of Api::ProjectsController and shown in place. The page's address stays as
// it is: the chart's island writes it, and Back stays the chart's. Its words
// are the server's (ProjectListSerializer). On the dashboard each row also
// has Edit and its stage switches, which send the view along (back).

export type ProjectsProps = {
  initial: ProjectListView
  // Api::ProjectsController's path for this builder, with dashboard=1 on
  // the dashboard.
  endpoint: string
}

type Ask = { sort: string; query: string; live: boolean; hidden: boolean; page: number }

// How long typing pauses before the list asks for what was typed.
const TYPING_MS = 250

export default function ProjectsIsland({ initial, endpoint }: ProjectsProps) {
  const fallback = initial.sorts[0]?.key ?? "latest"
  const { view, busy, failed, open, retry, prefetch } = useView(initial, listUrl(endpoint, askOf(initial), fallback), { own: [], restored: () => undefined })
  const [query, setQuery] = useState(initial.query)
  const top = useRef<HTMLDivElement>(null)
  const typing = useRef<number | undefined>(undefined)
  useEffect(() => () => window.clearTimeout(typing.current), [])

  const ask = (changes: Partial<Ask>) => ({ ...askOf(view), query, ...changes })
  const go = (changes: Partial<Ask>) => {
    window.clearTimeout(typing.current)
    open(listUrl(endpoint, ask(changes), fallback), () => window.location.href, undefined, "none")
  }
  const turn = (page: number) => {
    go({ page })
    if (top.current && top.current.getBoundingClientRect().top < 0) top.current.scrollIntoView({ block: "start" })
  }
  const warm = (page: number) => prefetch(listUrl(endpoint, ask({ page }), fallback))
  const typed = (next: string) => {
    setQuery(next)
    window.clearTimeout(typing.current)
    typing.current = window.setTimeout(() => go({ query: next, page: 1 }), TYPING_MS)
  }
  const submit = (event: FormEvent) => {
    event.preventDefault()
    go({ page: 1 })
  }

  return (
    <div ref={top} aria-busy={busy} className={`scroll-mt-6 transition-opacity ${busy ? "opacity-60" : ""}`}>
      <div className="os-between">
        <h3 className="os-h3 text-xl">{view.title}</h3>
        <div className="flex flex-wrap items-center gap-2 max-md:w-full">
          <form role="search" onSubmit={submit} className="max-md:w-full">
            <input type="search" name="q" value={query} onChange={(event) => typed(event.target.value)} placeholder="Find a project"
                   aria-label="Find a project" className="os-field h-9 w-56 max-md:w-full" />
          </form>
          <div className="os-pills" role="group" aria-label="Sort">
            {view.sorts.map((sort) => (
              <button key={sort.key} type="button" className="os-pill" aria-pressed={sort.key === view.sort} onClick={() => go({ sort: sort.key, page: 1 })}>{sort.label}</button>
            ))}
          </div>
          {view.liveLabel && (
            <button type="button" className="os-chip" aria-pressed={view.live} onClick={() => go({ live: !view.live, page: 1 })}>{view.liveLabel}</button>
          )}
          {view.hiddenLabel && (
            <button type="button" className="os-chip" aria-pressed={view.hidden} onClick={() => go({ hidden: !view.hidden, page: 1 })}>{view.hiddenLabel}</button>
          )}
        </div>
      </div>
      {failed && (
        <p role="status" className="os-note mt-3">
          That list did not load. <button type="button" className="os-link text-[13px]" onClick={retry}>Try again</button>
        </p>
      )}
      <div className="mt-3.5">
        <div className={`hidden gap-x-6 pb-2 text-xs font-bold text-ink-3 md:grid ${view.back ? GRID_MANAGE : GRID}`} aria-hidden="true">
          <span>Project</span><span>Last 12 months</span><span className="text-right">Last commit</span>{view.back && <span className="text-right">Your stage</span>}
        </div>
        {view.rows.map((row) => <ListRow key={row.key} row={row} fields={view.back} />)}
        <div className="flex flex-wrap items-center justify-between gap-3 border-t border-line pt-3.5">
          <span className="os-sm os-muted" aria-live="polite">{view.range ?? view.empty}</span>
          {view.pages > 1 && (
            <div className="flex gap-2">
              <button type="button" className="os-btn2 sm" disabled={view.page <= 1} onClick={() => turn(view.page - 1)}
                      onPointerEnter={() => view.page > 1 && warm(view.page - 1)}>Previous</button>
              <button type="button" className="os-btn2 sm" disabled={view.page >= view.pages} onClick={() => turn(view.page + 1)}
                      onPointerEnter={() => view.page < view.pages && warm(view.page + 1)}>Next</button>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// The list's columns, as profiles/page/_more_projects writes them: on the
// dashboard, a fourth for the stage switches.
const GRID = "md:grid-cols-[minmax(0,1fr)_220px_120px]"
const GRID_MANAGE = "md:grid-cols-[minmax(0,1fr)_220px_120px_88px]"

// One project, as profiles/page/_more_projects draws it: its name, a link to
// its page, with Live or Archived, its description on one line, its weekly
// line over 52 weeks in ink with their count, and its last commit; on the
// dashboard (fields), Edit beside its name and its stage switches last. On a
// phone the name and description take the row, the rest goes under it.
export function ListRow({ row, fields = null }: { row: ProjectListRow; fields?: [string, string][] | null }) {
  return (
    <div className={`grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-6 gap-y-1.5 border-t border-line py-2.5 ${fields ? GRID_MANAGE : GRID}`}>
      <div className="min-w-0 max-md:col-span-2">
        <div className="flex min-w-0 items-center gap-2">
          <a href={row.path} className="truncate text-[15px] font-bold hover:underline" data-turbo-frame="_top">{row.name}</a>
          {row.live && <span className="os-tag soft shrink-0">Live</span>}
          {row.archived && <span className="os-tag shrink-0">Archived</span>}
          {row.edit && <a href={row.edit} className="os-btn2 ml-auto h-[30px] shrink-0 rounded-[9px] px-3 text-[13px]" aria-label={`Edit ${row.name}`}>Edit</a>}
        </div>
        {row.description && <p className="os-xs os-muted mt-0.5 truncate">{row.description}</p>}
      </div>
      <div className="flex items-center gap-3">
        {row.line && (
          <>
            <svg viewBox="0 0 400 56" preserveAspectRatio="none" aria-hidden="true" className="h-6 w-[110px] flex-none overflow-visible md:w-[150px]">
              <path d={row.line} fill="none" className="stroke-ink-3" strokeWidth="1.75" vectorEffect="non-scaling-stroke" />
            </svg>
            <span className="os-num min-w-7 text-right text-[15px]">{row.commits}<span className="sr-only"> {row.countWords}</span></span>
          </>
        )}
      </div>
      <div className="os-sm os-ink2 text-right">{row.last && <><span className="sr-only">Last commit </span>{row.last}</>}</div>
      {fields && (
        <div className="whitespace-nowrap text-right max-md:col-span-2 max-md:text-left">
          <span className="os-xs os-muted mb-1 block md:hidden">Your stage</span>
          {row.page && <PageSwitch name={row.name} page={row.page} fields={fields} />}
          {row.pin && <PinSwitch name={row.name} pin={row.pin} fields={fields} />}
        </div>
      )}
    </div>
  )
}

function askOf(view: ProjectListView): Ask {
  return { sort: view.sort, query: view.query, live: view.live, hidden: view.hidden, page: view.page }
}

// The API's address for a view of the list, its defaults left out as
// Progress::Listing#to_params leaves them, so one view has one address, after
// the endpoint's own params (dashboard=1).
export function listUrl(endpoint: string, ask: Ask, fallback: string): string {
  const [path = endpoint, own = ""] = endpoint.split("?")
  const params = new URLSearchParams(own)
  if (ask.sort !== fallback) params.set("sort", ask.sort)
  if (ask.query.trim()) params.set("q", ask.query.trim())
  if (ask.live) params.set("live", "1")
  if (ask.hidden) params.set("hidden", "1")
  if (ask.page > 1) params.set("page", String(ask.page))
  const search = params.toString()
  return search ? `${path}?${search}` : path
}
