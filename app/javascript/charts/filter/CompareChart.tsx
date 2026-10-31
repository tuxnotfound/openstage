import { Fragment, useLayoutEffect, useRef, useState, type KeyboardEvent, type PointerEvent } from "react"
import type { CompareChartView, NumberView } from "../types"
import LineKey from "./LineKey"
import { LINE_DASHES, lineOf, noteOf, pathTops, tipLeft, type Lines } from "./lines"

// Draws a chart filter's chart as the server worked it out
// (CompareChartSerializer), as charts/_chart renders the same view: a line
// per project and number, in the project's colour and its number's line
// style by this page's line order. Hovering a point, dragging across it on
// a touch screen or moving with the arrow keys once the chart has focus
// shows a mark on each line there and one tooltip, a row per project with
// anything at that point and a column per number drawn, each followed by
// any the server shows beside it. A number or a project under the pointer
// or focus brings its lines forward.

const WIDTH = 1000
const HEIGHT = 280
// The others, while one number's or project's lines come forward.
const FADED = 0.14

export type Focus = { kind: "number" | "project"; key: string }
type Path = CompareChartView["paths"][number]
// A project's number, by its row's key and the number's: its line, or its
// value in the tooltip.
export type ProjectNumber = Pick<Path, "key" | "number">

type Props = {
  chart: CompareChartView
  numbers: NumberView[]
  lines: Lines
  focus: Focus | null
  height?: string
  // A project's number to leave out at once, its line and its value in the
  // tooltip, as a dashboard switch waits for its save.
  hidden?: (each: ProjectNumber) => boolean
}

export default function CompareChart({ chart, numbers, lines, focus, height = "", hidden }: Props) {
  const box = useRef<HTMLDivElement>(null)
  const [at, setAt] = useState<number | null>(null)
  const line = (path: Path) => lineOf(lines, path.number, chart.indexed)
  const paths = chart.paths.filter((path) => !hidden?.(path)).sort((a, b) => line(b) - line(a))
  const picked = (path: Path) => focus !== null && (focus.kind === "number" ? path.number === focus.key : path.key === focus.key)
  const lit = paths.some(picked)
  const hot = (path: Path) => !lit || picked(path)
  const index = at === null || chart.columns.length === 0 ? null : Math.min(at, chart.columns.length - 1)
  const column = index === null ? undefined : chart.columns[index]
  const x = column ? column.left + (column.width * column.mark) / 100 : 0
  const marks = index === null ? [] : paths.filter(hot).flatMap((path) => {
    const top = pathTops(path.d)[index]
    return top !== undefined && top < 99.95 ? [{ path, top }] : []
  })

  function pointAt(event: PointerEvent) {
    const rect = box.current?.getBoundingClientRect()
    if (!rect || rect.width === 0 || chart.columns.length === 0) return
    const percent = (100 * (event.clientX - rect.left)) / rect.width
    const found = chart.columns.findIndex((each) => percent >= each.left && percent < each.left + each.width)
    setAt(found === -1 ? (percent < 0 ? 0 : chart.columns.length - 1) : found)
  }

  function move(event: KeyboardEvent) {
    const last = chart.columns.length - 1
    if (event.key === "Escape") return setAt(null)
    const to = { ArrowLeft: (index ?? last + 1) - 1, ArrowRight: (index ?? -1) + 1, Home: 0, End: last }[event.key]
    if (to === undefined || last < 0) return undefined
    event.preventDefault()
    setAt(Math.max(0, Math.min(last, to)))
    return undefined
  }

  return (
    <div className="mt-[18px]">
      <div ref={box} tabIndex={0} role="group" aria-roledescription="chart" aria-label={`${chart.ariaLabel}. Arrow keys move from point to point.`}
           className={`os-chart ${height} touch-pan-y`}
           onPointerDown={pointAt} onPointerMove={pointAt} onPointerCancel={() => setAt(null)}
           onPointerLeave={(event) => { if (event.pointerType === "mouse") setAt(null) }}
           onKeyDown={move} onFocus={() => setAt((was) => was ?? chart.columns.length - 1)} onBlur={() => setAt(null)}>
        {chart.ticks.map((tick) => <div key={`grid-${tick.value}`} className="os-gridline" style={{ top: `${tick.top}%` }} />)}
        <div className="os-axis" />
        <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} preserveAspectRatio="none" aria-hidden="true">
          {paths.map((path) => (
            <path key={`${path.key}|${path.number}`} d={path.d} className={`${path.colorClass} stroke-(--project) transition-opacity duration-150`}
                  fill="none" strokeWidth="4.5" strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke"
                  strokeDasharray={LINE_DASHES[line(path)] || undefined} style={{ opacity: hot(path) ? 1 : FADED }} />
          ))}
        </svg>
        {chart.ticks.map((tick) => <div key={`label-${tick.value}`} className="os-ylab -translate-y-1/2" style={{ top: `${tick.top}%` }}>{tick.value}</div>)}
        <div className="absolute inset-y-0 right-0 w-0.5 bg-strong" aria-hidden="true" />
        {column && <div className="pointer-events-none absolute inset-y-0 z-[1] w-px bg-ink-3" style={{ left: `${x}%` }} aria-hidden="true" />}
        {marks.map(({ path, top }) => (
          <span key={`mark-${path.key}|${path.number}`} aria-hidden="true"
                className={`${path.colorClass} pointer-events-none absolute z-[3] -mt-[5px] -ml-[5px] size-2.5 rounded-full bg-(--project) shadow-[0_0_0_2px_var(--color-fill)]`}
                style={{ left: `${x}%`, top: `${top}%` }} />
        ))}
        {/* Mounted before any point is, so a screen reader hears the first one too. */}
        <div role="status" aria-live="polite" className="pointer-events-none absolute inset-0 z-[5]">
          {column && <Tip chart={chart} column={column} lines={lines} x={x} hidden={hidden} />}
        </div>
      </div>
      <div className="os-xlabs">
        {chart.axis.map((label, i) => <span key={`axis-${i}`} className={i === chart.axis.length - 1 ? "font-bold text-ink" : ""}>{label}</span>)}
      </div>
      <p className="os-note mt-2">{noteOf(chart, numbers, lines)}</p>
    </div>
  )
}

// One tooltip for the point: a row per project and a column per tip, with
// heads while there are two or more. A number drawn heads its column with
// its line, on a phone the line alone, so the table fits; one shown beside
// it has no line, so its name shows at every width. It never runs past the
// chart: its names give way first, and it sits beside the point while there
// is room, else against the chart's nearer edge. Its samples stay in place:
// .os-chart stretches every svg inside it over the chart. hidden: as the
// chart has it.
export function Tip({ chart, column, lines, x, hidden }: { chart: CompareChartView; column: CompareChartView["columns"][number]; lines: Lines; x: number; hidden?: Props["hidden"] }) {
  const box = useRef<HTMLDivElement>(null)
  const [left, setLeft] = useState<number | null>(null)
  const heads = chart.tips.length > 1 ? chart.tips : []

  useLayoutEffect(() => {
    const tip = box.current
    const span = tip?.parentElement?.clientWidth
    if (tip && span) setLeft(tipLeft(x, tip.offsetWidth, span))
  })

  return (
    <div ref={box} style={{ left: left ?? 0, visibility: left === null ? "hidden" : undefined }}
         className="absolute top-2 w-max max-w-[min(360px,calc(100%-8px))] rounded-[10px] bg-ink px-3 py-2.5 text-xs/snug text-ground shadow-lg">
      <div className="opacity-70">{column.title}</div>
      {column.rows.length === 0 ? <div className="mt-1">{chart.none}</div> : (
        <div className="mt-[7px] grid items-center gap-x-3 gap-y-[3px]" style={{ gridTemplateColumns: `minmax(0, max-content) repeat(${Math.max(1, chart.tips.length)}, max-content)` }}>
          {heads.length > 0 && (
            <>
              <span />
              {heads.map((head) => (
                <span key={head.key} className="inline-flex items-center justify-self-end gap-[5px] text-[11px] font-semibold whitespace-nowrap opacity-70">
                  {head.line && <LineKey line={lineOf(lines, head.key, chart.indexed)} className="static h-1.5 w-4" />}
                  <span className={head.line ? "max-md:sr-only" : undefined}>{head.label}</span>
                </span>
              ))}
            </>
          )}
          {column.rows.map((row) => (
            <Fragment key={row.key}>
              <span className="max-w-[150px] truncate">
                <span className={`os-dot ${row.colorClass} mr-[7px] bg-(--project) align-[-1px] shadow-[0_0_0_1.5px_var(--color-ground)]`} />{row.name}
              </span>
              {chart.tips.map((each, i) => (
                <span key={each.key} className="text-right font-bold whitespace-nowrap tabular-nums">{hidden?.({ key: row.key, number: each.key }) ? "–" : row.values[i]}</span>
              ))}
            </Fragment>
          ))}
        </div>
      )}
    </div>
  )
}
