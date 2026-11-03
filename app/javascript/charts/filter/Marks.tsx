import type { FocusEvent, MouseEvent } from "react"
import type { ChartMark } from "../types"

// The shipped and published entries on a chart (ProgressChart::Marks), as
// charts/_chart draws them: a disc in the project's colour on its line, or
// on the axis, with a rocket for something shipped and a speech bubble for
// something published, kept inside the chart at its edges. On a page that
// lists the entries (listed), a disc links to its newest entry's row and,
// with the script, opens a folded list, brings the rows into view and
// lights them up (reveal); the dashboard's discs only mark. Their titles
// are the tooltip's.

const ROCKET = "M14.5 1.5c-3.4.2-6.3 1.8-8.3 4.6L4.6 8.4l3 3 2.3-1.6c2.8-2 4.4-4.9 4.6-8.3Zm-2.6 4a1.4 1.4 0 1 1-2.8 0 1.4 1.4 0 0 1 2.8 0ZM6.2 6.1 2.6 5.9 1 7.6l3.6.8ZM9.9 9.8l.2 3.6L8.4 15l-.8-3.6ZM4.1 11.1c-1.2.3-2 1.2-2.4 3.2 2-.4 2.9-1.2 3.2-2.4Z"
const BUBBLE = "M3.5 2.5h9a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2H7.6L4.5 14v-2.5h-1a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2Z"

// static: .os-chart stretches every svg inside it over the chart.
export function MarkIcon({ shipped, className }: { shipped: boolean; className: string }) {
  return (
    <svg viewBox="0 0 16 16" className={`${className} static flex-none`} fill="currentColor" aria-hidden="true">
      <path d={shipped ? ROCKET : BUBBLE} fillRule="evenodd" />
    </svg>
  )
}

type Props = {
  mark: ChartMark
  // Its opacity while other lines come forward.
  opacity: number
  listed: boolean
  // Its point, for the tooltip, as the disc takes focus.
  onPoint: () => void
}

export default function Mark({ mark, opacity, listed, onPoint }: Props) {
  const css = `${mark.colorClass} absolute z-[4] -mt-[11px] -ml-[11px] inline-flex size-[22px] items-center justify-center rounded-full bg-(--project) text-(--on-project) shadow-[0_0_0_2px_var(--color-fill)] transition-opacity duration-150`
  const style = { left: `clamp(11px, ${mark.left}%, calc(100% - 11px))`, top: `min(${mark.top}%, calc(100% - 11px))`, opacity }
  const icon = <MarkIcon shipped={mark.shipped} className="size-[13px]" />
  if (!listed) return <span aria-hidden="true" className={`${css} pointer-events-none`} style={style}>{icon}</span>

  const ids = mark.entries.map((entry) => entry.id)
  function pick(event: MouseEvent) {
    if (reveal(ids)) event.preventDefault()
  }
  function focus(event: FocusEvent) {
    event.stopPropagation()
    onPoint()
  }
  return (
    <a href={`#entry-${ids[0]}`} aria-label={mark.label} onClick={pick} onFocus={focus} style={style}
       className={`${css} cursor-pointer before:absolute before:-inset-1 before:content-[''] hover:scale-110 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink`}>
      {icon}
    </a>
  )
}

// Brings entries' rows in the page's list into view (What shipped, a
// project's What's new), opening the list where they are folded away, and
// lights them up again; false when none is on the page, so the link's own
// anchor takes over.
export function reveal(ids: number[]): boolean {
  const rows = ids.map((id) => document.getElementById(`entry-${id}`)).filter((row): row is HTMLElement => row !== null)
  const first = rows[0]
  if (!first) return false
  rows.forEach((row) => {
    const fold = row.closest("details")
    if (fold) fold.open = true
  })
  const still = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  first.scrollIntoView({ behavior: still ? "auto" : "smooth", block: "center" })
  rows.forEach((row) => {
    row.classList.remove("os-picked")
    void row.offsetWidth
    row.classList.add("os-picked")
  })
  return true
}
