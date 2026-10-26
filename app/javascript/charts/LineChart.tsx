import { useRef, useState, type MouseEvent } from "react"
import type { ChartView, Rank } from "./types"

// Draws a chart the server worked out (ChartSerializer): the lines, the
// gridlines, the axis and a tooltip per point, as the profiles/page/_chart
// partial renders the same view.

const WIDTH = 1000
const HEIGHT = 280

// The class that gives marks a project's colour, as ProgressHelper#project_class.
export function projectClass(rank: Rank): string {
  if (rank === null) return "os-project-none"
  return rank < 6 ? `os-project-${rank + 1}` : "os-project-other"
}

type Props = {
  chart: ChartView
  height?: string
  // Names each line under the chart, where nothing beside it does.
  legend?: boolean
  // Charts stacked on the same points share one hover: the point every one
  // of them marks, its tooltip beside the line, and what to tell the others.
  shared?: number | null
  onHover?: (index: number | null) => void
}

export default function LineChart({ chart, height = "", legend = false, shared, onHover }: Props) {
  const box = useRef<HTMLDivElement>(null)
  const tip = useRef<HTMLDivElement>(null)
  const [own, setOwn] = useState<{ index: number; left: number; top: number } | null>(null)
  const stacked = shared !== undefined

  function place(event: MouseEvent, index: number) {
    onHover?.(index)
    if (stacked) return
    const rect = box.current?.getBoundingClientRect()
    if (!rect) return
    const tipW = tip.current?.offsetWidth || 220
    const tipH = tip.current?.offsetHeight || 40
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top
    setOwn({ index, left: Math.max(4, Math.min(x - tipW / 2, rect.width - tipW - 4)), top: Math.max(4, y - tipH - 10) })
  }

  const hover = stacked ? sharedPlace(shared ?? null) : own
  const hovered = hover ? chart.columns[hover.index] : undefined

  // Beside the point's line, on whichever side has room, at the chart's top.
  function sharedPlace(index: number | null) {
    const column = index === null ? undefined : chart.columns[index]
    const width = box.current?.offsetWidth ?? 0
    if (!column || index === null || !width) return null
    const x = ((column.left + (column.width * column.mark) / 100) / 100) * width
    const tipW = tip.current?.offsetWidth || 220
    return { index, left: x + 12 + tipW > width ? Math.max(4, x - tipW - 12) : x + 12, top: 4 }
  }

  return (
    <div>
      <div ref={box} className={`os-chart ${height}`} onMouseLeave={() => (stacked ? undefined : setOwn(null))}>
        {chart.ticks.map((tick) => <div key={`grid-${tick.value}`} className="os-gridline" style={{ top: `${tick.top}%` }} />)}
        <div className="os-axis" />
        <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} preserveAspectRatio="none" role="img" aria-label={chart.ariaLabel}>
          {chart.paths.map((path, i) => (
            <path key={`${i}-${path.rank}`} d={path.d} className={`${projectClass(path.rank)} stroke-(--project)`} fill="none" strokeWidth="4.5"
                  strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
          ))}
        </svg>
        {chart.ticks.map((tick) => <div key={`label-${tick.value}`} className="os-ylab -translate-y-1/2" style={{ top: `${tick.top}%` }}>{tick.value}</div>)}
        <div className="absolute inset-y-0 right-0 w-0.5 bg-strong" aria-hidden="true" />
        {chart.columns.map((column, i) => (
          <div key={`column-${i}`} className="group absolute inset-y-0 z-[2]" style={{ left: `${column.left}%`, width: `${column.width}%` }}
               onMouseEnter={(event) => place(event, i)} onMouseMove={(event) => place(event, i)}>
            <div className={`absolute inset-y-0 w-px bg-ink-3 ${stacked ? (shared === i ? "opacity-100" : "opacity-0") : "opacity-0 group-hover:opacity-100"}`}
                 style={{ left: `${column.mark}%` }} />
          </div>
        ))}
        <div ref={tip} className={`pointer-events-none absolute z-[5] w-[220px] rounded-[10px] bg-ink px-3 py-2.5 text-xs/snug text-ground shadow-lg ${hovered ? "" : "hidden"}`}
             style={hover ? { left: hover.left, top: hover.top } : undefined}>
          {hovered && (
            <>
              <div className="opacity-70">{hovered.title}{chart.average ? " · 7-day average" : ""}</div>
              {hovered.rows.length === 0 && <div className="mt-1">{chart.none}</div>}
              {hovered.rows.map((row) => (
                <div key={row.name} className="mt-1 flex items-center gap-2">
                  <span className={`${projectClass(row.rank)} h-1 w-3 rounded-sm ${row.rank === null ? "bg-ground" : "bg-(--project)"}`} />
                  <span className="flex-1">{row.name}</span>
                  <span className="font-semibold tabular-nums">{row.value}</span>
                </div>
              ))}
            </>
          )}
        </div>
      </div>
      <div className="os-xlabs">
        {chart.axis.map((label, i) => <span key={`axis-${i}`} className={i === chart.axis.length - 1 ? "font-bold text-ink" : ""}>{label}</span>)}
      </div>
      {legend && chart.legend.length > 1 && (
        <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-1.5 text-[13px] text-ink-2" aria-label="Lines">
          {chart.legend.map((line) => (
            <li key={line.name} className="inline-flex items-center gap-2">
              <span className={`${projectClass(line.rank)} h-1 w-3.5 rounded-sm bg-(--project)`} aria-hidden="true" />{line.name}
            </li>
          ))}
        </ul>
      )}
      <p className="os-note mt-2">{chart.empty ? chart.emptyNote : chart.note}</p>
    </div>
  )
}
