import { useRef, useState, type MouseEvent } from "react"
import { ticks as scaleTicks } from "./scale"

// One line per project or page, in its colour, with a tooltip per point: the
// chart the server's profiles/page/_chart partial draws, recomputed here so a
// click redraws it at once.

export type ChartLine = { key: string; name: string; rank: number | null; values: number[] }

type Props = {
  lines: ChartLine[]
  // One title per point, for its tooltip.
  titles: string[]
  axis: string[]
  ariaLabel: string
  note: string
  emptyNote: string
  // The 30-day page view averages, so values show a decimal and the floor is 1.
  average?: boolean
  // A tooltip's words for a point where every line is at zero.
  none?: string
  height?: string
}

const WIDTH = 1000
const HEIGHT = 280
const HEADROOM = 1.1

// The class that gives marks a project's colour, as ProgressHelper#project_class.
export function projectClass(rank: number | null): string {
  if (rank === null) return "os-project-none"
  return rank < 6 ? `os-project-${rank + 1}` : "os-project-other"
}

// 12.5 or 12, never 12.0, so the paths stay short.
function num(value: number): string {
  return String(Math.round(value * 100) / 100)
}

export default function LineChart({ lines, titles, axis, ariaLabel, note, emptyNote, average = false, none = "No commits", height = "" }: Props) {
  const box = useRef<HTMLDivElement>(null)
  const tip = useRef<HTMLDivElement>(null)
  const [hover, setHover] = useState<{ index: number; left: number; top: number } | null>(null)

  const count = titles.length
  const scale = scaleTicks(Math.max(...lines.flatMap((line) => line.values), average ? 1 : 4))
  const ceiling = (scale[scale.length - 1] ?? 1) * HEADROOM
  const x = (i: number) => (count === 1 ? WIDTH / 2 : (i * WIDTH) / (count - 1))
  const y = (value: number) => HEIGHT * (1 - value / ceiling)
  const top = (value: number) => Math.round((100 - (100 * value) / ceiling) * 100) / 100
  const pct = (value: number) => Math.round(((100 * value) / WIDTH) * 100) / 100

  const columns = titles.map((title, i) => {
    const from = i === 0 ? 0 : (x(i - 1) + x(i)) / 2
    const to = i === count - 1 ? WIDTH : (x(i) + x(i + 1)) / 2
    const rows = lines
      .filter((line) => (line.values[i] ?? 0) > 0)
      .sort((a, b) => (b.values[i] ?? 0) - (a.values[i] ?? 0))
      .map((line) => ({ key: line.key, name: line.name, rank: line.rank, value: average ? (line.values[i] ?? 0).toFixed(1) : String(line.values[i] ?? 0) }))
    return { title, rows, left: pct(from), width: pct(to - from), mark: Math.round(((100 * (x(i) - from)) / (to - from)) * 10) / 10 }
  })

  function place(event: MouseEvent, index: number) {
    const rect = box.current?.getBoundingClientRect()
    if (!rect) return
    const tipW = tip.current?.offsetWidth || 220
    const tipH = tip.current?.offsetHeight || 40
    const pointX = event.clientX - rect.left
    const pointY = event.clientY - rect.top
    setHover({ index, left: Math.max(4, Math.min(pointX - tipW / 2, rect.width - tipW - 4)), top: Math.max(4, pointY - tipH - 10) })
  }

  const hovered = hover ? columns[hover.index] : undefined

  return (
    <div>
      <div ref={box} className={`os-chart ${height}`} onMouseLeave={() => setHover(null)}>
        {scale.slice(1).map((value) => (
          <div key={`grid-${value}`} className="os-gridline" style={{ top: `${top(value)}%` }} />
        ))}
        <div className="os-axis" />
        <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} preserveAspectRatio="none" role="img" aria-label={ariaLabel}>
          {[...lines].reverse().map((line) => (
            <path key={line.key} d={line.values.map((value, i) => `${i === 0 ? "M" : "L"}${num(x(i))} ${num(y(value))}`).join(" ")}
                  className={`${projectClass(line.rank)} stroke-(--project)`} fill="none" strokeWidth="4.5"
                  strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
          ))}
        </svg>
        {scale.slice(1).map((value) => (
          <div key={`label-${value}`} className="os-ylab -translate-y-1/2" style={{ top: `${top(value)}%` }}>{value}</div>
        ))}
        <div className="absolute inset-y-0 right-0 w-0.5 bg-strong" aria-hidden="true" />
        {columns.map((column, i) => (
          <div key={`column-${i}`} className="group absolute inset-y-0 z-[2]" style={{ left: `${column.left}%`, width: `${column.width}%` }}
               onMouseEnter={(event) => place(event, i)} onMouseMove={(event) => place(event, i)}>
            <div className="absolute inset-y-0 w-px bg-ink-3 opacity-0 group-hover:opacity-100" style={{ left: `${column.mark}%` }} />
          </div>
        ))}
        <div ref={tip} className={`pointer-events-none absolute z-[5] w-[220px] rounded-[10px] bg-ink px-3 py-2.5 text-xs/snug text-ground shadow-lg ${hovered ? "" : "hidden"}`}
             style={hover ? { left: hover.left, top: hover.top } : undefined}>
          {hovered && (
            <>
              <div className="opacity-70">{hovered.title}{average ? " · 7-day average" : ""}</div>
              {hovered.rows.length === 0 && <div className="mt-1">{none}</div>}
              {hovered.rows.map((row) => (
                <div key={row.key} className="mt-1 flex items-center gap-2">
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
        {axis.map((label, i) => (
          <span key={`axis-${i}`} className={i === axis.length - 1 ? "font-bold text-ink" : ""}>{label}</span>
        ))}
      </div>
      <p className="os-note mt-2">{lines.length > 0 ? note : emptyNote}</p>
    </div>
  )
}
