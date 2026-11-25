import { useEffect, useLayoutEffect, useRef, useState, type RefObject } from "react"
import { csrfToken } from "../filter/ProjectsTable"
import type { DashboardLine, DashboardLines, DashboardList, DashboardRow, DashboardView, SyncLogView } from "../types"

// The dashboard's Projects tab: the list, a project and its one switch a
// row, and nothing selected when the page opens. A click on a project reads
// its numbers and brings them in from the right (the stylesheet's .dt-two);
// a second click, Close or Escape sends them back, and the focus goes back
// to its row. ?project= in the address opens a project's numbers, so a
// reload keeps what was open and Set up site visits comes back to them;
// ?row= opens the list on a project's row. Every switch saves the way it
// saves today, and a row keeps its place when its switch flips. Every word
// but the tab's own is the server's.

export type ProjectsTabProps = {
  initial: DashboardList
  // The list's API; a project's numbers are at its address plus "/id".
  endpoint: string
  open: DashboardLines | null
  row: number | null
  history: SyncLogView[]
}

type Ask = { view: DashboardView; query: string; page: number }

// A view of the list's address, its defaults left out.
export function listUrl(endpoint: string, ask: Ask): string {
  const params = new URLSearchParams()
  params.set("view", ask.view)
  if (ask.query.trim()) params.set("q", ask.query.trim())
  if (ask.page > 1) params.set("page", String(ask.page))
  return `${endpoint}?${params}`
}

// The page's own address with a project's numbers open, or none.
export function pageUrl(href: string, project: number | null): string {
  const url = new URL(href)
  url.searchParams.delete("row")
  if (project === null) url.searchParams.delete("project")
  else url.searchParams.set("project", String(project))
  return url.toString()
}

// A view read again after a row's switch saved: the counts are the new
// ones, and every row stays where it was, in its new state, even one that
// has left the view, so nothing moves under the pointer.
export function keepPlace(current: DashboardList, fresh: DashboardList): DashboardList {
  return { ...fresh, rows: current.rows.map((row) => fresh.rows.find((each) => each.id === row.id) ?? row) }
}

async function send(path: string, body: Record<string, unknown>): Promise<boolean> {
  const response = await fetch(path, {
    method: "PATCH", credentials: "same-origin",
    headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": csrfToken() },
    body: JSON.stringify(body),
  }).catch(() => null)
  if (response?.ok) window.Turbo?.cache.exemptPageFromCache()
  return !!response?.ok
}

async function read<T>(path: string): Promise<T | null> {
  const response = await fetch(path, { credentials: "same-origin", headers: { Accept: "application/json" } }).catch(() => null)
  return response?.ok ? ((await response.json()) as T) : null
}

export default function ProjectsTab({ initial, endpoint, open: opened, row: landing, history }: ProjectsTabProps) {
  const [list, setList] = useState(initial)
  const [query, setQuery] = useState(initial.query)
  const [shown, setShown] = useState<DashboardLines | null>(opened)
  const [open, setOpen] = useState(opened !== null)
  const [failed, setFailed] = useState<"list" | "lines" | "switch" | null>(null)
  const picks = useRef(new Map<number, HTMLButtonElement>())
  const name = useRef<HTMLHeadingElement>(null)
  const typing = useRef<number | undefined>(undefined)
  const moved = useRef(false)
  const selected = open && shown ? shown.id : null

  const ask = (changes: Partial<Ask>): Ask => ({ view: list.view, query, page: list.page, ...changes })

  async function view(next: Ask) {
    const fresh = await read<DashboardList>(listUrl(endpoint, next))
    setFailed(fresh ? null : "list")
    if (fresh) setList(fresh)
  }

  async function bring(id: number) {
    const lines = await read<DashboardLines>(`${endpoint}/${id}`)
    if (!lines) return setFailed("lines")
    setFailed(null)
    moved.current = true
    setShown(lines)
    setOpen(true)
    window.history.replaceState(window.history.state, "", pageUrl(window.location.href, id))
  }

  function close() {
    if (!shown) return
    moved.current = true
    setOpen(false)
    window.history.replaceState(window.history.state, "", pageUrl(window.location.href, null))
  }

  // The focus follows what came in, and goes back to its row once it leaves.
  useLayoutEffect(() => {
    if (!moved.current) return
    moved.current = false
    if (open) name.current?.focus({ preventScroll: true })
    else if (shown) picks.current.get(shown.id)?.focus()
  }, [open, shown])

  useEffect(() => {
    if (!open) return
    const onKey = (event: KeyboardEvent) => { if (event.key === "Escape") close() }
    document.addEventListener("keydown", onKey)
    return () => document.removeEventListener("keydown", onKey)
  })

  // ?row= lands on a project's row: in view, its switch focused.
  useEffect(() => {
    if (landing === null) return
    const pick = picks.current.get(landing)
    pick?.scrollIntoView({ block: "center" })
    pick?.closest(".dt-row")?.querySelector<HTMLButtonElement>("[role=switch]")?.focus({ preventScroll: true })
  }, [landing])

  function find(value: string) {
    setQuery(value)
    window.clearTimeout(typing.current)
    typing.current = window.setTimeout(() => { void view({ view: list.view, query: value, page: 1 }) }, 250)
  }

  async function flipStage(row: DashboardRow) {
    const next = !row.stage
    setFailed(null)
    setList((was) => ({ ...was, rows: was.rows.map((each) => (each.id === row.id ? { ...each, stage: next } : each)) }))
    if (!(await send(row.switch, { included: String(next) }))) {
      setList((was) => ({ ...was, rows: was.rows.map((each) => (each.id === row.id ? { ...each, stage: row.stage } : each)) }))
      return setFailed("switch")
    }
    const fresh = await read<DashboardList>(listUrl(endpoint, ask({})))
    if (fresh) setList((was) => keepPlace(was, fresh))
    if (shown?.id === row.id) await again(row.id)
  }

  async function flipLine(line: DashboardLine) {
    const control = line.control
    if (control.kind !== "switch" || control.dead || !shown) return
    const next = !control.on
    const project = shown.id
    setFailed(null)
    setShown((was) => was && { ...was, lines: was.lines.map((each) => (each.key === line.key ? { ...each, control: { ...control, on: next } } : each)) })
    const saved = await send(control.path, control.number ? { number: control.number, shown: next } : { pinned: next })
    if (!saved) setFailed("switch")
    await again(project)
    if (saved && !control.number) await view(ask({}))
  }

  // A project's numbers read again once a switch saved, or did not.
  async function again(id: number) {
    const lines = await read<DashboardLines>(`${endpoint}/${id}`)
    if (lines) setShown((was) => (was?.id === id ? lines : was))
  }

  return (
    <div className={`dt-two${open ? " open" : ""}`}>
      <section className="os-panel dt-panel dt-list" aria-label="Projects">
        {list.many && (
          <div className="dt-tools">
            <div className="os-pills" role="group" aria-label="Which projects">
              {list.views.map((each) => (
                <button key={each.key} type="button" className="os-pill" aria-pressed={each.key === list.view}
                        onClick={() => { void view({ view: each.key, query, page: 1 }) }}>{each.label} {each.count}</button>
              ))}
            </div>
            <input type="search" className="os-field dt-find" placeholder="Find a project" aria-label="Find a project" value={query}
                   onChange={(event) => find(event.target.value)} />
          </div>
        )}
        <div className="dt-head dt-lgrid" aria-hidden="true"><span>Project</span><span className="sw">On your stage</span></div>
        {list.rows.map((row) => (
          <div key={row.id} className={`dt-row dt-lgrid${row.stage ? "" : " off"}${row.id === selected ? " sel" : ""}`}>
            <button type="button" className={`dt-pick dt-name ${row.colorClass ?? ""}`} aria-expanded={row.id === selected}
                    aria-label={`${row.id === selected ? "Close" : "Show"} the numbers of ${row.name}`}
                    ref={(element) => { if (element) picks.current.set(row.id, element); else picks.current.delete(row.id) }}
                    onClick={() => { if (row.id === selected) close(); else void bring(row.id) }}>
              {row.colorClass ? <span className="os-dot bg-(--project)" aria-hidden="true" /> : <span className="dt-nodot" aria-hidden="true" />}
              <span className="dt-pick-name" title={row.name}>{row.name}</span>
              <span className="dt-chev" aria-hidden="true" />
            </button>
            <div className="dt-cell">
              <button type="button" role="switch" aria-checked={row.stage} aria-label={`Show ${row.name} on your stage`} className="os-switch"
                      onClick={() => { void flipStage(row) }} />
            </div>
          </div>
        ))}
        {list.empty && <p className="dt-empty">{list.empty}{list.connect && <> <a href={list.connect} className="os-link text-[13px]">Connect GitHub</a></>}</p>}
        {failed === "list" && <p role="status" className="os-note mt-2">That list did not load. <button type="button" className="os-link text-[13px]" onClick={() => { void view(ask({})) }}>Try again</button></p>}
        {failed === "switch" && !open && <p role="status" className="os-note mt-2">That switch did not save. Try it again.</p>}
        {failed === "lines" && <p role="status" className="os-note mt-2">That view did not load. Try it again.</p>}
        {list.pages > 1 && (
          <div className="dt-pager">
            <span className="os-sm os-muted">{list.range}</span>
            <span className="dt-pager-btns">
              <button type="button" className={`os-btn2 dt-small${list.page <= 1 ? " led" : ""}`} aria-disabled={list.page <= 1}
                      onClick={() => { if (list.page > 1) void view(ask({ page: list.page - 1 })) }}>Previous</button>
              <button type="button" className={`os-btn2 dt-small${list.page >= list.pages ? " led" : ""}`} aria-disabled={list.page >= list.pages}
                      onClick={() => { if (list.page < list.pages) void view(ask({ page: list.page + 1 })) }}>Next</button>
            </span>
          </div>
        )}
        <History history={history} />
      </section>
      <div className="dt-side" inert={!open}>
        {shown && (
          <div className="os-panel dt-side-in">
            <Numbers lines={shown} name={name} close={close} flip={(line) => { void flipLine(line) }} failed={failed === "switch"} />
          </div>
        )}
      </div>
    </div>
  )
}

// What comes in: the project's colour and name, its page, Edit and Close,
// or under 901 px the way back; then a line per number.
export function Numbers({ lines, name, close, flip, failed }: {
  lines: DashboardLines; name?: RefObject<HTMLHeadingElement | null>; close: () => void; flip: (line: DashboardLine) => void; failed: boolean
}) {
  return (
    <section className="dt-pane" aria-label={`The numbers of ${lines.name}`}>
      <button type="button" className="dt-back" onClick={close}><span className="dt-chev back" aria-hidden="true" />Projects</button>
      <div className="dt-pane-head">
        <h2 className={`os-h3 dt-pane-name ${lines.colorClass ?? ""}`} tabIndex={-1} ref={name}>
          {lines.colorClass && <span className="os-dot bg-(--project)" aria-hidden="true" />}{lines.name}
        </h2>
        <span className="dt-pane-links">
          <a href={lines.page} className="os-btn2 dt-small">Its page <span aria-hidden="true">↗</span></a>
          <a href={lines.edit} className="os-btn2 dt-small" aria-label={`Edit ${lines.name}`}>Edit</a>
          <button type="button" className="os-btn2 dt-small dt-close" aria-label={`Close the numbers of ${lines.name}`} onClick={close}>Close</button>
        </span>
      </div>
      <div className="dt-line-head" aria-hidden="true"><span>Number</span><span>Visitors see</span></div>
      {lines.lines.map((line) => (
        <div key={line.key} className={`dt-line${line.sep ? " sep" : ""}`}>
          <div className="dt-line-what"><span className="dt-line-name">{line.name}</span><span className="dt-line-state">{line.state}</span></div>
          <div className="dt-line-do"><Control line={line} flip={flip} /></div>
        </div>
      ))}
      {failed && <p role="status" className="os-note mt-2">That switch did not save. Try it again.</p>}
    </section>
  )
}

function Control({ line, flip }: { line: DashboardLine; flip: (line: DashboardLine) => void }) {
  const control = line.control
  if (control.kind === "pro") return <span className="os-tag pro">✦ Pro</span>
  if (control.kind === "link") return <a href={control.path} className={control.filled ? "os-btn sm" : "os-btn2 sm"} aria-label={control.aria}>{control.label}</a>
  return (
    <button type="button" role="switch" aria-checked={control.on} aria-disabled={control.dead} aria-label={control.aria}
            className={`os-switch${control.dead ? " led" : ""}`} onClick={() => flip(line)} />
  )
}

const DOT: Record<SyncLogView["state"], string> = { up: "bg-up", down: "bg-down", warn: "bg-warn" }

// The last syncs, at the list's foot, as the dashboard has them today.
function History({ history }: { history: SyncLogView[] }) {
  if (history.length === 0) return null
  return (
    <details className="dt-history">
      <summary>Sync history</summary>
      <ul>
        {history.map((log, i) => (
          <li key={i}>
            <span><i className={DOT[log.state]} />{log.source}{log.added ? <span className="os-muted"> +{log.added}</span> : null}</span>
            <time className="os-muted">{log.ago}</time>
          </li>
        ))}
      </ul>
    </details>
  )
}
