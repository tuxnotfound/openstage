import { useEffect, useLayoutEffect, useRef, useState, type KeyboardEvent, type RefObject } from "react"
import type { CalendarView } from "../types"
import {
  EARLIEST, WEEKDAY_NAMES, addMonths, clamp, dayLabel, monthLabel, monthOf, monthsHolding, moved, openingMonths, ordered, sameDayIn, shortDay,
  weeksOf, within, type Day, type Month, type Picked,
} from "./days"

// The window's calendar: a dialog under the Custom pill. Two months side by
// side from 768 px, one below that, opening on the days picked, else on
// today's month with the month before it on its left. A click or Enter on a
// day picks the first day, a second the last, in either order, and that
// applies them and closes it; until then the pointer and keyboard focus
// preview the span. Days after today and before the first day anything
// here counted are off. The keyboard moves as the WAI-ARIA date picker
// dialog does (days.ts); Tab stays inside, Escape or a click outside closes
// it, and focus goes back to the pill.

const WIDE = "(min-width: 768px)"
// Room kept from the screen's edges.
const GUTTER = 16

type Props = {
  calendar: CalendarView
  // The pill it hangs from, which gets focus back.
  pill: RefObject<HTMLButtonElement | null>
  pick: (days: Picked) => void
  // outside: closed by a press outside it, which may have given focus elsewhere.
  close: (outside: boolean) => void
}

export default function Calendar({ calendar, pill, pick, close }: Props) {
  const box = useRef<HTMLDivElement>(null)
  const min = calendar.earliest && calendar.earliest > EARLIEST ? calendar.earliest : EARLIEST
  const max = calendar.today
  const count = useWide() ? 2 : 1
  const [months, setMonths] = useState<Month[]>(() => openingMonths(calendar.picked, max, count))
  const [focus, setFocus] = useState<Day>(() => clamp(calendar.picked?.to ?? max, min, max))
  const [first, setFirst] = useState<Day | null>(null)
  const [hover, setHover] = useState<Day | null>(null)
  // Whether the day in focus takes the keyboard's focus once drawn: on
  // opening and after a key moves it, never after a month button.
  const follow = useRef(true)
  const left = useAnchored(box, pill, count)

  useEffect(() => { setMonths((was) => (was.length === count ? was : openingMonths(calendar.picked, max, count))) }, [count, calendar.picked, max])
  // Once placed: a box still hidden takes no focus.
  useEffect(() => {
    if (!follow.current || left === null) return
    follow.current = false
    box.current?.querySelector<HTMLButtonElement>("button[tabindex='0']")?.focus()
  }, [focus, months, left])
  useOutside(box, pill, () => close(true))

  const span = first ? ordered(first, hover ?? focus) : calendar.picked
  const off = (day: Day) => day < min || day > max

  function go(day: Day) {
    const next = clamp(day, min, max)
    follow.current = true
    setFocus(next)
    setMonths((was) => monthsHolding(was, next))
  }

  // A month button moves the months, and the day in focus with them.
  function page(count: number) {
    setMonths((was) => was.map((month) => addMonths(month, count)))
    setFocus((was) => clamp(sameDayIn(was, count), min, max))
  }

  function choose(day: Day) {
    if (off(day)) return
    if (!first) {
      setFirst(day)
      setHover(day)
      return
    }
    pick(ordered(first, day))
  }

  function key(event: KeyboardEvent) {
    if (event.key === "Escape") {
      event.preventDefault()
      return close(false)
    }
    if (event.key === "Tab") return trap(event, box.current)
    const target = event.target as HTMLElement
    if (!target.dataset.day) return
    const next = moved(focus, event.key, event.shiftKey)
    if (next === null) return
    event.preventDefault()
    setHover(null)
    go(next)
  }

  const firstShown = months[0] ?? max
  const lastShown = months[months.length - 1] ?? max
  return (
    <div ref={box} role="dialog" aria-modal="true" aria-label="Custom range" onKeyDown={key} style={{ left: left ?? 0, visibility: left === null ? "hidden" : undefined }}
         className="absolute top-full z-30 mt-2 w-max rounded-card border border-line bg-surface p-4 text-ink shadow-lg">
      <div className="relative">
        <MonthButton label="Previous month" disabled={firstShown <= monthOf(min)} onClick={() => page(-1)} side="left" />
        <MonthButton label="Next month" disabled={lastShown >= monthOf(max)} onClick={() => page(1)} side="right" />
        <div className="flex gap-6">
          {months.map((month) => (
            <MonthGrid key={month} month={month} focus={focus} span={span} today={max} off={off}
                       choose={choose} hover={(day) => { if (first) setHover(day) }} focused={(day) => { setFocus(day); if (first) setHover(day) }} />
          ))}
        </div>
      </div>
      <p role="status" className="mt-3 text-[13px] font-semibold text-ink-2">
        {first ? `From ${shortDay(first)}. Pick the last day.` : "Pick the first day."}
      </p>
    </div>
  )
}

function MonthButton({ label, disabled, onClick, side }: { label: string; disabled: boolean; onClick: () => void; side: "left" | "right" }) {
  return (
    <button type="button" aria-label={label} disabled={disabled} onClick={onClick}
            className={`absolute top-0 ${side === "left" ? "left-0" : "right-0"} inline-flex size-9 items-center justify-center rounded-full text-ink-2 hover:bg-fill disabled:cursor-default disabled:opacity-35 disabled:hover:bg-transparent`}>
      <svg viewBox="0 0 16 16" className="size-4" aria-hidden="true">
        <path d={side === "left" ? "M10 3 5 8l5 5" : "m6 3 5 5-5 5"} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    </button>
  )
}

type GridProps = {
  month: Month
  focus: Day
  // The days picked, or the span the pointer or focus previews.
  span: Picked | null
  today: Day
  off: (day: Day) => boolean
  choose: (day: Day) => void
  hover: (day: Day) => void
  focused: (day: Day) => void
}

function MonthGrid({ month, focus, span, today, off, choose, hover, focused }: GridProps) {
  const heading = `calendar-${month}`
  return (
    <div className="w-[280px]">
      <h2 id={heading} className="flex h-9 items-center justify-center text-sm font-bold">{monthLabel(month)}</h2>
      <table role="grid" aria-labelledby={heading} className="mt-2 w-full border-collapse text-center text-[13px]">
        <thead>
          <tr>
            {WEEKDAY_NAMES.map((name) => <th key={name} scope="col" abbr={name} className="h-8 font-semibold text-ink-3">{name.slice(0, 2)}</th>)}
          </tr>
        </thead>
        <tbody>
          {weeksOf(month).map((week) => (
            <tr key={week.find(Boolean) ?? month}>
              {week.map((day, i) => day === null ? <td key={`${month}-${i}`} className="p-0" /> : (
                <DayCell key={day} day={day} focus={day === focus} span={span} today={day === today} off={off(day)}
                         choose={choose} hover={hover} focused={focused} />
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

type CellProps = Omit<GridProps, "month" | "focus" | "today" | "off"> & { day: Day; focus: boolean; today: boolean; off: boolean }

function DayCell({ day, focus, span, today, off, choose, hover, focused }: CellProps) {
  const inside = within(day, span)
  const end = span !== null && (day === span.from || day === span.to)
  const band = inside && span !== null && span.from !== span.to
    ? `${day === span.from ? "rounded-l-full" : ""} ${day === span.to ? "rounded-r-full" : ""} bg-accent-soft`
    : ""
  const tone = off ? "text-ink-3 opacity-40" : end ? "bg-accent text-on-accent" : inside ? "text-accent-ink" : "text-ink hover:bg-fill"
  return (
    <td className={`p-0 ${band}`} aria-selected={inside}>
      <button type="button" data-day={day} tabIndex={focus ? 0 : -1} disabled={off} aria-label={dayLabel(day)} aria-current={today ? "date" : undefined}
              onClick={() => choose(day)} onPointerEnter={() => hover(day)} onFocus={() => focused(day)}
              className={`relative inline-flex size-10 items-center justify-center rounded-full font-semibold tabular-nums ${tone} ${today ? "underline decoration-2 underline-offset-4" : ""} disabled:cursor-default`}>
        {Number(day.slice(8))}
      </button>
    </td>
  )
}

// Two months where the screen is wide enough, else one.
function useWide(): boolean {
  const [wide, setWide] = useState(() => typeof window !== "undefined" && window.matchMedia(WIDE).matches)
  useEffect(() => {
    const query = window.matchMedia(WIDE)
    const change = () => setWide(query.matches)
    query.addEventListener("change", change)
    return () => query.removeEventListener("change", change)
  }, [])
  return wide
}

// Its left edge under the pill, from the box it sits in: its right edge
// under the pill's, moved in so it stays GUTTER from the screen's edges.
function useAnchored(box: RefObject<HTMLDivElement | null>, pill: RefObject<HTMLButtonElement | null>, months: number): number | null {
  const [left, setLeft] = useState<number | null>(null)
  useLayoutEffect(() => {
    function place() {
      const own = box.current
      const anchor = pill.current
      const parent = own?.offsetParent
      if (!own || !anchor || !parent) return
      const width = own.offsetWidth
      const wanted = anchor.getBoundingClientRect().right - width
      const fits = Math.max(GUTTER, Math.min(wanted, document.documentElement.clientWidth - GUTTER - width))
      setLeft(Math.round(fits - parent.getBoundingClientRect().left))
    }
    place()
    window.addEventListener("resize", place)
    return () => window.removeEventListener("resize", place)
  }, [box, pill, months])
  return left
}

// A press outside the calendar and its pill closes it; focus goes back to
// the pill unless the press gave it to something else.
function useOutside(box: RefObject<HTMLDivElement | null>, pill: RefObject<HTMLButtonElement | null>, close: () => void) {
  const latest = useRef(close)
  useLayoutEffect(() => { latest.current = close })
  useEffect(() => {
    function press(event: PointerEvent) {
      const target = event.target as Node
      if (box.current?.contains(target) || pill.current?.contains(target)) return
      latest.current()
    }
    document.addEventListener("pointerdown", press)
    return () => document.removeEventListener("pointerdown", press)
  }, [box, pill])
}

// Tab and Shift+Tab go round the calendar's own controls.
function trap(event: KeyboardEvent, box: HTMLElement | null) {
  const stops = [...(box?.querySelectorAll<HTMLButtonElement>("button:not([disabled]):not([tabindex='-1'])") ?? [])]
  const first = stops[0]
  const last = stops[stops.length - 1]
  if (!first || !last) return
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first.focus()
  }
}
