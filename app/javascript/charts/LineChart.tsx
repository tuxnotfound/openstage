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

// legend: names each line under the chart, where nothing beside it does.
export default function LineChart({ chart, height = "", legend = false }: { chart: ChartView; height?: string; legend?: boolean }) {
  const box = useRef<HTMLDivElement>(null)
  const tip = useRef<HTMLDivElement>(null)
  const [hover, setHover] = useState<{ index: number; left: number; top: number } | null>(null)

  function place(event: MouseEvent, index: number) {
    const rect = box.current?.getBoundingClientRect()
    if (!rect) return
    const tipW = tip.current?.offsetWidth || 220
    const tipH = tip.current?.offsetHeight || 40
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top
    setHover({ index, left: Math.max(4, Math.min(x - tipW / 2, rect.width - tipW - 4)), top: Math.max(4, y - tipH - 10) })
  }

  const hovered = hover ? chart.columns[hover.index] : undefined

  return (
    <div>
      <div ref={box} className={`os-chart ${height}`} onMouseLeave={() => setHover(null)}>
        {chart.ticks.map((tick) => <div key={`grid-${tick.value}`} className="os-gridline" style={{ top: `${tick.top}%` }} />)}
        <div className="os-axis" />
        <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} preserveAspectRatio="none" role="img" aria-label={chart.ariaLabel}>
          {chart.paths.map((path, i) => (
            <path key={`${i}-${path.rank}`} d={path.d} className={`${projectClass(path.rank)} stroke-(--project)`} fill="none" strokeWidth="4.5"
                  strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" strokeDasharray={path.dashed ? "2 9" : undefined} />
          ))}
        </svg>
        {chart.ticks.map((tick) => <div key={`label-${tick.value}`} className="os-ylab -translate-y-1/2" style={{ top: `${tick.top}%` }}>{tick.value}</div>)}
        <div className="absolute inset-y-0 right-0 w-0.5 bg-strong" aria-hidden="true" />
        {chart.columns.map((column, i) => (
          <div key={`column-${i}`} className="group absolute inset-y-0 z-[2]" style={{ left: `${column.left}%`, width: `${column.width}%` }}
               onMouseEnter={(event) => place(event, i)} onMouseMove={(event) => place(event, i)}>
            <div className="absolute inset-y-0 w-px bg-ink-3 opacity-0 group-hover:opacity-100" style={{ left: `${column.mark}%` }} />
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
              <span className={`${projectClass(line.rank)} w-3.5 ${line.dashed ? "border-t-[3px] border-dotted border-(--project)" : "h-1 rounded-sm bg-(--project)"}`} aria-hidden="true" />{line.name}
            </li>
          ))}
        </ul>
      )}
      <p className="os-note mt-2">{chart.empty ? chart.emptyNote : chart.note}</p>
    </div>
  )
}
