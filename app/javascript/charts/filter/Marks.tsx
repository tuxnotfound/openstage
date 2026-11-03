import type { FocusEvent, MouseEvent } from "react"
import type { Badge, ChartMark } from "../types"

// The shipped and published entries on a chart (ProgressChart::Marks), as
// charts/_chart draws them: a disc in the project's colour on its line, or
// on the axis, with a flag for a milestone, a rocket for anything else
// shipped and a speech bubble for what was published, kept inside the chart
// at its edges. A disc leads to its newest entry (lead): its row in the
// page's What's new, or the dashboard's entries; with the script it opens
// whatever folds the rows away, brings them into view and lights them up
// (reveal), and on the dashboard, where the list loads a page at a time, it
// opens the list on the entry first. Without a lead a disc only marks.
// Their titles are the tooltip's.

// Where a disc leads.
export type Lead = "news" | "entries"

const ICONS: Record<Badge, string> = {
  milestone: "M3 1.5a.8.8 0 0 1 .8.8v.4h8.9c.5 0 .8.6.5 1L11.1 6.4l2.1 2.7c.3.4 0 1-.5 1H3.8v4.6a.8.8 0 0 1-1.6 0V2.3a.8.8 0 0 1 .8-.8Z",
  shipped: "M14.5 1.5c-3.4.2-6.3 1.8-8.3 4.6L4.6 8.4l3 3 2.3-1.6c2.8-2 4.4-4.9 4.6-8.3Zm-2.6 4a1.4 1.4 0 1 1-2.8 0 1.4 1.4 0 0 1 2.8 0ZM6.2 6.1 2.6 5.9 1 7.6l3.6.8ZM9.9 9.8l.2 3.6L8.4 15l-.8-3.6ZM4.1 11.1c-1.2.3-2 1.2-2.4 3.2 2-.4 2.9-1.2 3.2-2.4Z",
  published: "M3.5 2.5h9a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2H7.6L4.5 14v-2.5h-1a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2Z",
}

// static: .os-chart stretches every svg inside it over the chart.
export function MarkIcon({ badge, className }: { badge: Badge; className: string }) {
  return (
    <svg viewBox="0 0 16 16" className={`${className} static flex-none`} fill="currentColor" aria-hidden="true">
      <path d={ICONS[badge]} fillRule="evenodd" />
    </svg>
  )
}

type Props = {
  mark: ChartMark
  // Its opacity while other lines come forward.
  opacity: number
  lead?: Lead
  // Its point, for the tooltip, as the disc takes focus.
  onPoint: () => void
}

export default function Mark({ mark, opacity, lead, onPoint }: Props) {
  const css = `${mark.colorClass} absolute z-[4] -mt-[11px] -ml-[11px] inline-flex size-[22px] items-center justify-center rounded-full bg-(--project) text-(--on-project) shadow-[0_0_0_2px_var(--color-fill)] transition-opacity duration-150`
  const style = { left: `clamp(11px, ${mark.left}%, calc(100% - 11px))`, top: `min(${mark.top}%, calc(100% - 11px))`, opacity }
  const icon = <MarkIcon badge={mark.badge} className="size-[13px]" />
  if (!lead) return <span aria-hidden="true" className={`${css} pointer-events-none`} style={style}>{icon}</span>

  const ids = mark.entries.map((entry) => entry.id)
  const first = ids[0] ?? 0
  function pick(event: MouseEvent) {
    if (reveal(ids)) {
      event.preventDefault()
    } else if (lead === "entries" && window.Turbo) {
      event.preventDefault()
      openEntries(first, ids)
    }
  }
  function focus(event: FocusEvent) {
    event.stopPropagation()
    onPoint()
  }
  return (
    <a href={lead === "news" ? `#entry-${first}` : entriesHref(first, typeof window === "undefined" ? "/dashboard" : window.location.href)}
       aria-label={mark.label} onClick={pick} onFocus={focus} style={style}
       className={`${css} cursor-pointer before:absolute before:-inset-1 before:content-[''] hover:scale-110 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ink`}>
      {icon}
    </a>
  )
}

// Brings entries' rows into view (What's new, the dashboard's entries),
// opening each that folds away or holds a description, and the dashboard's
// tab they sit in, and lights them up again; false when none is on the page.
export function reveal(ids: number[]): boolean {
  const rows = ids.map((id) => document.getElementById(`entry-${id}`)).filter((row): row is HTMLElement => row !== null)
  const first = rows[0]
  if (!first) return false
  rows.forEach((row) => {
    for (let fold = row.closest("details"); fold; fold = fold.parentElement?.closest("details") ?? null) fold.open = true
    const panel = row.closest<HTMLElement>("[data-tabs-panel]")
    if (panel?.classList.contains("hidden")) document.querySelector<HTMLElement>(`[data-tabs-tab="${panel.dataset.tabsPanel}"]`)?.click()
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

// The dashboard with its entries opened on one (EntriesSection), the
// entries' own filters and page left out, the chart's kept: from href, the
// page's address.
export function entriesHref(id: number, href: string): string {
  const url = new URL(href, "http://openstage.invalid")
  ;["q", "type", "repo", "tab", "before"].forEach((key) => url.searchParams.delete(key))
  url.searchParams.set("entry", String(id))
  url.hash = `entry-${id}`
  return `${url.pathname}${url.search}${url.hash}`
}

// Opens the dashboard's entries on an entry in their frame, then reveals
// the mark's rows.
function openEntries(id: number, ids: number[]) {
  const frame = document.getElementById("entries-lists")
  const href = entriesHref(id, window.location.href)
  if (!frame) {
    window.location.assign(href)
    return
  }
  frame.addEventListener("turbo:frame-load", () => reveal(ids), { once: true })
  window.Turbo?.visit(href, { frame: "entries-lists", action: "advance" })
}
