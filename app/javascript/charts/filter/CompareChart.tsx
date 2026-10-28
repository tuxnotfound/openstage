import { useRef, useState, type KeyboardEvent, type PointerEvent } from "react"
import { projectClass } from "../LineChart"
import type { CompareChartView, NumberView } from "../types"
import LineKey from "./LineKey"
import { LINE_DASHES, lineOf, noteOf, pathTops, type Lines } from "./lines"

// Draws a chart filter's chart as the server worked it out
// (CompareChartSerializer), as charts/_chart renders the same view: a line
// per project and number, in the project's colour and its number's line
// style by this page's line order. Hovering a point, dragging across it on
// a touch screen or moving with the arrow keys once the chart has focus
// shows a mark on each line there and one tooltip, a row per project with
// anything at that point and a column per number. A number or a project
// under the pointer or focus brings its lines forward.

const WIDTH = 1000
const HEIGHT = 280
// The others, while one number's or project's lines come forward.
const FADED = 0.14

export type Focus = { kind: "number" | "project"; key: string }
type Path = CompareChartView["paths"][number]

type Props = {
  chart: CompareChartView
  numbers: NumberView[]
  lines: Lines
  focus: Focus | null
  height?: string
  // A line to leave out at once, as a dashboard switch waits for its save.
  hidden?: (path: Path) => boolean
}

export default function CompareChart({ chart, numbers, lines, focus, height = "", hidden }: Props) {
  const box = useRef<HTMLDivElement>(null)
  const [at, setAt] = useState<number | null>(null)
  const line = (path: Path) => lineOf(lines, path.number, chart.indexed)
  const paths = chart.paths.filter((path) => !hidden?.(path)).sort((a, b) => line(b) - line(a))
  const picked = (path: Path) => focus !== null && (focus.kind === "number" ? path.number === focus.key : path.repo === focus.key)
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
      <div ref={box} tabIndex={0} aria-label={`${chart.ariaLabel}. Arrow keys move from point to point.`}
           className={`os-chart ${height} touch-pan-y`}
           onPointerDown={pointAt} onPointerMove={pointAt} onPointerCancel={() => setAt(null)}
           onPointerLeave={(event) => { if (event.pointerType === "mouse") setAt(null) }}
           onKeyDown={move} onFocus={() => setAt((was) => was ?? chart.columns.length - 1)} onBlur={() => setAt(null)}>
        {chart.ticks.map((tick) => <div key={`grid-${tick.value}`} className="os-gridline" style={{ top: `${tick.top}%` }} />)}
        <div className="os-axis" />
        <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} preserveAspectRatio="none" role="img" aria-label={chart.ariaLabel}>
          {paths.map((path) => (
            <path key={`${path.repo}|${path.number}`} d={path.d} className={`${projectClass(path.rank)} stroke-(--project) transition-opacity duration-150`}
                  fill="none" strokeWidth="4.5" strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke"
                  strokeDasharray={LINE_DASHES[line(path)] || undefined} style={{ opacity: hot(path) ? 1 : FADED }} />
          ))}
        </svg>
        {chart.ticks.map((tick) => <div key={`label-${tick.value}`} className="os-ylab -translate-y-1/2" style={{ top: `${tick.top}%` }}>{tick.value}</div>)}
        <div className="absolute inset-y-0 right-0 w-0.5 bg-strong" aria-hidden="true" />
        {column && <div className="pointer-events-none absolute inset-y-0 z-[1] w-px bg-ink-3" style={{ left: `${x}%` }} aria-hidden="true" />}
        {marks.map(({ path, top }) => (
          <span key={`mark-${path.repo}|${path.number}`} aria-hidden="true"
                className={`${projectClass(path.rank)} pointer-events-none absolute z-[3] -mt-[5px] -ml-[5px] size-2.5 rounded-full bg-(--project) shadow-[0_0_0_2px_var(--color-fill)]`}
                style={{ left: `${x}%`, top: `${top}%` }} />
        ))}
        {column && <Tip chart={chart} column={column} numbers={numbers} lines={lines} x={x} />}
      </div>
      <div className="os-xlabs">
        {chart.axis.map((label, i) => <span key={`axis-${i}`} className={i === chart.axis.length - 1 ? "font-bold text-ink" : ""}>{label}</span>)}
      </div>
      <p className="os-note mt-2">{noteOf(chart, numbers, lines)}</p>
    </div>
  )
}

// One tooltip for the point: a row per project, a column per number, each
// column headed by its line when there are several. Its samples stay in
// place: .os-chart stretches every svg inside it over the chart.
function Tip({ chart, column, numbers, lines, x }: { chart: CompareChartView; column: CompareChartView["columns"][number]; numbers: NumberView[]; lines: Lines; x: number }) {
  const label = (key: string) => numbers.find((number) => number.key === key)?.label ?? key
  return (
    <div role="status" aria-live="polite" style={x > 50 ? { right: `calc(${100 - x}% + 14px)` } : { left: `calc(${x}% + 14px)` }}
         className="pointer-events-none absolute top-2 z-[5] max-w-[min(360px,72%)] rounded-[10px] bg-ink px-3 py-2.5 text-xs/snug text-ground shadow-lg">
      <div className="opacity-70">{column.title}</div>
      {column.rows.length === 0 ? <div className="mt-1">{chart.none}</div> : (
        <table className="mt-1 border-collapse">
          {chart.heads.length > 1 && (
            <thead>
              <tr>
                <th />
                {chart.heads.map((key) => (
                  <th key={key} scope="col" className="pt-[3px] pl-3 text-right text-[11px] font-semibold whitespace-nowrap opacity-70">
                    <span className="inline-flex items-center gap-[5px]"><LineKey line={lineOf(lines, key, chart.indexed)} className="static h-1.5 w-4" />{label(key)}</span>
                  </th>
                ))}
              </tr>
            </thead>
          )}
          <tbody>
            {column.rows.map((row) => (
              <tr key={row.repo}>
                <th scope="row" className="max-w-[150px] truncate pt-[3px] text-left font-normal">
                  <span className={`os-dot ${projectClass(row.rank)} mr-[7px] bg-(--project) align-[-1px] shadow-[0_0_0_1.5px_var(--color-ground)]`} />{row.name}
                </th>
                {row.values.map((value, i) => <td key={chart.heads[i] ?? i} className="pt-[3px] pl-3 text-right font-bold whitespace-nowrap tabular-nums">{value}</td>)}
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}
