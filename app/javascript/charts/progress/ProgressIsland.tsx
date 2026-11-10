import { useEffect, useLayoutEffect, useRef, useState } from "react"
import { createPortal } from "react-dom"
import CompareChart, { type ProjectNumber } from "../filter/CompareChart"
import { MarkIcon } from "../filter/Marks"
import NumberToggles from "../filter/NumberToggles"
import ProjectsTable, { csrfToken, type CellSwitches } from "../filter/ProjectsTable"
import WindowPills from "../filter/WindowPills"
import { lineOrder } from "../filter/lines"
import { useFilter } from "../filter/useFilter"
import type { ProgressRange, ProgressView, ShippedItem, TableCell, TableRow, TableView } from "../types"

// The chart filter on a builder's page, a project's page and the dashboard
// (useFilter): the numbers above the chart, the window, the chart, and the
// projects' table under it. The dashboard's switches save what visitors
// see, then ask for the view again.

export type ProgressProps = {
  initial: ProgressView
  // Api::ProgressController's path for this builder, with any params of its
  // own: a project page's project (and reveal, for one the builder hid), or
  // the dashboard's dashboard.
  endpoint: string
  mode: "page" | "project" | "dashboard"
  defaultRange: ProgressRange
  // The What's new section to keep in step, by element id.
  shippedTarget?: string
  // What its builder can do while the chart has nothing to draw, on their own
  // pages alone (chart_step). The page sends it, not the view, which a shared
  // cache holds for everyone.
  step?: { text: string; label: string; href: string } | null
}

const SHOWN = 8

export default function ProgressIsland({ initial, endpoint, mode, defaultRange, shippedTarget, step }: ProgressProps) {
  // A builder's page drops its old repo[]; the dashboard's repo filters its entries.
  const filter = useFilter(initial, { endpoint, defaultRange, named: mode !== "project", dropped: mode === "page" ? ["repo", "repo[]"] : [] })
  const { view, busy, failed, lines, focus } = filter
  const cells = useCellSwitches(view, filter.reload)

  const toggles = <NumberToggles numbers={view.numbers} lines={lines} indexed={view.chart.indexed} changes={mode === "dashboard"} {...filter.numbers} />
  const pills = <WindowPills range={view.range} calendar={view.calendar} target={filter.window} className={mode === "dashboard" ? "" : "max-md:flex max-md:w-full max-md:justify-between"} />
  const shipped = shippedTarget ? document.getElementById(shippedTarget) : null

  return (
    <div aria-busy={busy} className={`transition-opacity ${busy ? "opacity-60" : ""}`}>
      {mode === "dashboard" ? (
        <>
          <div className="os-between">
            <h2 id="your-activity" className="os-h2">Your activity</h2>
            {pills}
          </div>
          <div className="mt-5">{toggles}</div>
        </>
      ) : (
        <div className="flex flex-wrap items-center justify-between gap-x-6 gap-y-3">{toggles}{pills}</div>
      )}
      <p role="status" className="mt-2.5 text-[13px] font-semibold text-ink-2 empty:mt-0">{filter.notice}</p>
      <CompareChart chart={view.chart} lines={lines} focus={focus} height={mode === "dashboard" ? "h-[260px]" : ""}
                    hidden={mode === "dashboard" ? cells.hidden : undefined} lead={mode === "dashboard" ? "entries" : "news"} />
      {step && view.chart.paths.length === 0 && (
        <p className="os-note mt-2" data-chart-step>{step.text} <a className="os-link text-[13px]" href={step.href} data-turbo="false">{step.label}</a></p>
      )}
      {view.table && (
        <ProjectsTable table={view.table} drawn={lineOrder(lines)} lines={lines} indexed={view.chart.indexed} words={view.words}
                       focused={focus?.kind === "project" ? focus.key : null} rows={filter.rows} switches={mode === "dashboard" ? cells.switches : undefined} />
      )}
      {failed && (
        <p role="status" className="os-note mt-3">
          That view did not load. <button type="button" className="os-link text-[13px]" onClick={filter.retry}>Try again</button>
        </p>
      )}
      {mode === "dashboard" && cells.failed && <p role="status" className="os-note mt-2">That switch did not save. Try it again.</p>}
      {shipped && view.shipped && createPortal(<Shipped shipped={view.shipped} />, shipped)}
    </div>
  )
}

// The dashboard's switches: a switch answers at once, and a number switched
// off leaves the chart at once, its line and its value in the tooltip, with
// any value beside it, whose cell reads hidden with no switch (pendingCells);
// the save goes to the server, which then draws the view on screen by then
// again, on its new scale, and Back fetches the page anew rather than
// Turbo's copy from before the switch. A failed save puts it back.
function useCellSwitches(view: ProgressView, redraw: () => void): { switches: CellSwitches; hidden: (each: ProjectNumber) => boolean; failed: boolean } {
  const [pending, setPending] = useState<Record<string, boolean>>({})
  const [failed, setFailed] = useState(false)
  const latest = useRef(redraw)
  useLayoutEffect(() => { latest.current = redraw })

  // A switch the server settles is no longer pending.
  useEffect(() => {
    setPending((was) => stillPending(was, view.table))
  }, [view])

  const key = (row: TableRow, cell: TableCell) => `${row.key}|${cell.key}`
  const { pick, shown } = pendingCells(pending, view.table)

  async function flip(row: TableRow, cell: TableCell) {
    const current = pick(row, cell)
    if (!row.switch || cell.pick === null || current === null) return
    const next = !current
    const which = key(row, cell)
    setFailed(false)
    setPending((was) => ({ ...was, [which]: next }))
    const response = await fetch(row.switch, {
      method: "PATCH", credentials: "same-origin",
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": csrfToken() },
      body: JSON.stringify({ number: cell.key, shown: next }),
    }).catch(() => null)
    if (response?.ok) {
      window.Turbo?.cache.exemptPageFromCache()
      return latest.current()
    }
    setPending((was) => Object.fromEntries(Object.entries(was).filter(([each]) => each !== which)))
    setFailed(true)
  }

  return {
    switches: { pick, shown, flip: (row, cell) => { void flip(row, cell) } },
    hidden: (each) => pending[`${each.key}|${each.number}`] === false,
    failed,
  }
}

// The switches still pending, by row and cell key, once a view arrives: one
// the server now agrees with is not, nor one it no longer offers, as site
// visitors lose theirs while the site visits they sit beside are hidden.
export function stillPending(pending: Record<string, boolean>, table: TableView | null): Record<string, boolean> {
  return Object.fromEntries(Object.entries(pending).filter(([key, pick]) => {
    const cut = key.lastIndexOf("|")
    const row = table?.rows.find((each) => each.key === key.slice(0, cut))
    const cell = row?.cells.find((each) => each.key === key.slice(cut + 1))
    return cell !== undefined && cell.pick !== null && cell.pick !== pick
  }))
}

// The table's cells while switches wait for their save (pending, by row and
// cell key): each reads as its switch was flipped, and one beside a number
// switched off reads hidden, with no switch, as the server sends it once
// that save lands (Progress::Row#pick); a failed save brings it back.
export function pendingCells(pending: Record<string, boolean>, table: TableView | null): Pick<CellSwitches, "pick" | "shown"> {
  const off = (row: TableRow, cell: TableCell) => {
    const beside = table?.columns.find((each) => each.key === cell.key)?.beside
    return !!beside && pending[`${row.key}|${beside}`] === false
  }
  return {
    pick: (row, cell) => (off(row, cell) ? null : pending[`${row.key}|${cell.key}`] ?? cell.pick),
    shown: (row, cell) => !off(row, cell) && (pending[`${row.key}|${cell.key}`] ?? cell.shown),
  }
}

// What's new, as profiles/page/_whats_new draws it: every row is on the
// page, the ones past the first eight folded away, so a mark on the chart
// can open the fold to reach its row (Marks.reveal).
function Shipped({ shipped }: { shipped: NonNullable<ProgressView["shipped"]> }) {
  const items = shipped.items
  return (
    <>
      <div className="os-between">
        <h2 id="whats-new" className="os-h2">What's new</h2>
        {shipped.heading && <span className="os-xs os-muted">{shipped.heading}</span>}
      </div>
      {items.length === 0 ? (
        <p className="os-note mt-3">{shipped.empty}</p>
      ) : (
        <div className="mt-2.5">
          {items.slice(0, SHOWN).map((item, i) => <NewsRow key={item.id} item={item} open={i === 0} />)}
          {items.length > SHOWN && (
            <details className="group/all">
              <summary className="os-btn2 sm mt-3 list-none group-open/all:hidden [&::-webkit-details-marker]:hidden">Show all {items.length}</summary>
              {items.slice(SHOWN).map((item) => <NewsRow key={item.id} item={item} open={false} />)}
            </details>
          )}
        </div>
      )}
    </>
  )
}

// One entry of What's new, as profiles/page/_whats_new_row draws it: its
// day, its mark and kind, its title (a link to its link, through the click
// counter) and its project; with a description, a row that opens on it,
// whose run-in shows only while closed. open: open from the start.
export function NewsRow({ item, open }: { item: ShippedItem; open: boolean }) {
  const line = (
    <>
      <span className="os-sm os-muted flex-[0_0_64px]">{item.date}</span>
      <span className="os-xs inline-flex flex-[0_0_104px] items-center gap-1.5 font-bold text-ink-3">
        <span className={`${item.colorClass} inline-flex size-[18px] flex-none items-center justify-center rounded-full bg-(--project) text-(--on-project)`}>
          <MarkIcon badge={item.badge} className="size-[11px]" />
        </span>
        {item.kind}
      </span>
      <span className="min-w-0 flex-[1_1_300px] text-[15px] font-semibold">
        {item.url ? <a href={`/e/${item.id}/out`} target="_blank" rel="noopener" data-turbo="false" className="hover:underline" title={item.url}>{item.title}</a> : item.title}
        {item.runIn && <span className="font-normal text-ink-3 group-open/row:hidden">{item.runIn}</span>}
      </span>
      {item.project && <span className="os-xs os-muted">{item.project}</span>}
    </>
  )
  if (!item.body) return <div id={item.anchor ?? undefined} className="os-row os-rowflex scroll-mt-6 py-3">{line}</div>
  return (
    <details id={item.anchor ?? undefined} open={open} className="os-row group/row scroll-mt-6 py-3">
      <summary className="os-rowflex relative cursor-pointer list-none pr-7 [&::-webkit-details-marker]:hidden">
        {line}
        <svg viewBox="0 0 16 16" className="absolute top-0.5 right-0 size-4 text-ink-3 transition-transform group-open/row:rotate-180" fill="none" stroke="currentColor"
             strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="m4 6 4 4 4-4" /></svg>
      </summary>
      <p className="os-sm os-ink2 mt-1.5 whitespace-pre-line">{item.body}</p>
    </details>
  )
}
