import { useRef, useState } from "react"
import type { CalendarView, ProgressRange } from "../types"
import type { Target } from "../useView"
import Calendar from "./Calendar"
import { rangeParam } from "./days"

// The window, at the top right of what it scopes, the same on every chart
// page: four ranges, each asking for its view on click and warming it when
// the pointer or focus reaches it, and Custom, which opens the calendar
// (Calendar) and names the days picked while they are on screen. On a
// phone, Custom is its calendar icon alone until days are picked, and the
// pills sit a little closer, so all five fit a 390 px screen; with days
// picked, Custom takes a row of its own, so their dates stay whole.

const RANGES: [ProgressRange, string][] = [["30d", "30 days"], ["90d", "90 days"], ["12m", "12 months"], ["all", "All time"]]

type Props = { range: ProgressRange; calendar: CalendarView; target: (range: ProgressRange) => Target; className?: string }

export default function WindowPills({ range, calendar, target, className = "" }: Props) {
  const pill = useRef<HTMLButtonElement>(null)
  const [open, setOpen] = useState(false)
  const picked = calendar.picked

  function close(outside: boolean) {
    setOpen(false)
    if (!outside) return pill.current?.focus()
    // A press outside that gave focus to nothing leaves it on the pill.
    requestAnimationFrame(() => { if (document.activeElement === document.body || document.activeElement === null) pill.current?.focus() })
  }

  return (
    <div className={`os-pills ${className}`} role="group" aria-label="Time range">
      {RANGES.map(([value, label]) => {
        const to = target(value)
        return (
          <button key={value} type="button" className="os-pill max-md:px-2" aria-pressed={value === range}
                  onClick={to.go} onPointerEnter={to.warm} onFocus={to.warm}>{label}</button>
        )
      })}
      <span className={`relative ${picked ? "max-md:basis-full" : ""}`}>
        <button ref={pill} type="button" className={`os-pill gap-1.5 max-md:px-2 ${picked ? "max-md:w-full max-md:justify-center" : ""}`}
                aria-pressed={picked !== null} aria-haspopup="dialog" aria-expanded={open} onClick={() => (open ? close(false) : setOpen(true))}>
          <CalendarIcon />
          <span className={picked ? "" : "max-md:sr-only"}>{picked ? picked.name : "Custom"}</span>
        </button>
        {open && (
          <Calendar calendar={calendar} pill={pill} close={close}
                    pick={(days) => { close(false); target(rangeParam(days)).go() }} />
        )}
      </span>
    </div>
  )
}

// As IconsHelper#calendar_icon draws it for the first paint.
function CalendarIcon() {
  return (
    <svg viewBox="0 0 24 24" className="size-3.5 flex-none" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
      <rect x="3.5" y="5" width="17" height="15" rx="2.5" />
      <path d="M3.5 10h17M8 3v4M16 3v4" />
    </svg>
  )
}
