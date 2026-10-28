import { useEffect, useLayoutEffect, useRef, useState } from "react"
import { createPortal } from "react-dom"
import CompareChart from "../filter/CompareChart"
import NumberToggles from "../filter/NumberToggles"
import ProjectsTable, { csrfToken, type CellSwitches } from "../filter/ProjectsTable"
import WindowPills from "../filter/WindowPills"
import { lineOrder } from "../filter/lines"
import { useFilter } from "../filter/useFilter"
import type { CompareChartView, ProgressRange, ProgressView, ShippedItem, TableCell, TableRow } from "../types"

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
  // The What shipped section to keep in step, by element id.
  shippedTarget?: string
}

const SHOWN = 8

export default function ProgressIsland({ initial, endpoint, mode, defaultRange, shippedTarget }: ProgressProps) {
  // A builder's page drops its old repo[]; the dashboard's repo filters its entries.
  const filter = useFilter(initial, { endpoint, defaultRange, named: mode !== "project", dropped: mode === "page" ? ["repo", "repo[]"] : [] })
  const { view, busy, failed, lines, focus } = filter
  const cells = useCellSwitches(view, filter.reload)

  const toggles = <NumberToggles numbers={view.numbers} lines={lines} indexed={view.chart.indexed} changes={mode === "dashboard"} {...filter.numbers} />
  const pills = <WindowPills range={view.range} target={filter.window} className={mode === "dashboard" ? "" : "max-md:flex max-md:w-full max-md:justify-between"} />
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
      <CompareChart chart={view.chart} numbers={view.numbers} lines={lines} focus={focus} height={mode === "dashboard" ? "h-[260px]" : ""}
                    hidden={mode === "dashboard" ? cells.hidden : undefined} />
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

// The dashboard's switches: a switch answers at once, and a line switched
// off leaves the chart at once; the save goes to the server, which then
// draws the view on screen by then again, on its new scale, and Back fetches
// the page anew rather than Turbo's copy from before the switch. A failed
// save puts it back.
function useCellSwitches(view: ProgressView, redraw: () => void): { switches: CellSwitches; hidden: (path: CompareChartView["paths"][number]) => boolean; failed: boolean } {
  const [pending, setPending] = useState<Record<string, boolean>>({})
  const [failed, setFailed] = useState(false)
  const latest = useRef(redraw)
  useLayoutEffect(() => { latest.current = redraw })

  // A switch the server now agrees with is no longer pending.
  useEffect(() => {
    setPending((was) => Object.fromEntries(Object.entries(was).filter(([key, pick]) => {
      const cut = key.lastIndexOf("|")
      const row = view.table?.rows.find((each) => each.key === key.slice(0, cut))
      const cell = row?.cells.find((each) => each.key === key.slice(cut + 1))
      return cell ? cell.pick !== pick : false
    })))
  }, [view])

  const key = (row: TableRow, cell: TableCell) => `${row.key}|${cell.key}`
  const pick = (row: TableRow, cell: TableCell) => pending[key(row, cell)] ?? cell.pick

  async function flip(row: TableRow, cell: TableCell) {
    if (!row.switch || cell.pick === null) return
    const next = !pick(row, cell)
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
    switches: { pick, shown: (row, cell) => pending[key(row, cell)] ?? cell.shown, flip: (row, cell) => { void flip(row, cell) } },
    hidden: (path) => pending[`${path.key}|${path.number}`] === false,
    failed,
  }
}

function Shipped({ shipped }: { shipped: NonNullable<ProgressView["shipped"]> }) {
  const [all, setAll] = useState(false)
  const items = shipped.items
  return (
    <>
      <div className="os-between">
        <h2 id="what-shipped" className="os-h2">What shipped</h2>
        <span className="os-xs os-muted">{shipped.heading}</span>
      </div>
      {items.length === 0 ? (
        <p className="os-note mt-3">{shipped.empty}</p>
      ) : (
        <div className="mt-2.5">
          {(all ? items : items.slice(0, SHOWN)).map((item) => <ShippedRow key={item.id} item={item} />)}
          {!all && items.length > SHOWN && <button type="button" className="os-btn2 sm mt-3" onClick={() => setAll(true)}>Show all {items.length}</button>}
        </div>
      )}
    </>
  )
}

function ShippedRow({ item }: { item: ShippedItem }) {
  return (
    <div id={item.anchor ?? undefined} className="os-row os-rowflex scroll-mt-6 py-3">
      <span className="os-sm os-muted flex-[0_0_64px]">{item.date}</span>
      <span className="os-xs flex-[0_0_84px] font-bold text-ink-3">{item.kind}</span>
      <span className="min-w-0 flex-[1_1_300px] text-[15px] font-semibold">
        {item.url ? <a href={`/e/${item.id}/out`} target="_blank" rel="noopener" data-turbo="false" className="hover:underline" title={item.url}>{item.title}</a> : item.title}
        {item.runIn && <span className="font-normal text-ink-3">{item.runIn}</span>}
      </span>
      {item.project && <span className="os-xs os-muted">{item.project}</span>}
    </div>
  )
}
