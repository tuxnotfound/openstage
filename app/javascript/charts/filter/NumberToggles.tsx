import { useLayoutEffect, useRef, useState, type ReactNode } from "react"
import type { Change, NumberView } from "../types"
import LineKey from "./LineKey"
import { MAX_DRAWN, fitting, lineOf, projectClass, type Lines } from "./lines"

// The numbers above the chart, one row of toggles: a number's line while it
// is drawn (a plus when not), its name, its total for the rows in view, a
// thin bar of how that splits across them in their colours, and on the
// dashboard and analytics its change. On analytics they sit in their groups,
// each named before its toggles (On GitHub, On your websites, On
// Openstage). What does not fit the row folds behind "+ n more", measured
// as the row's width changes, whole groups at a time; it opens in a second
// row, which stays open while one of its numbers is drawn, so no drawn
// number hides.

const GAP = 8
// Between groups, and before the more button when there are groups.
const GROUP_GAP = 16

export type NumberEvents = {
  toggle: (key: string) => void
  warm: (key: string) => void
  // A number under the pointer or focus brings its lines forward; null lets go.
  focus: (key: string | null) => void
}

type Props = NumberEvents & {
  numbers: NumberView[]
  lines: Lines
  // Whether the chart compares numbers; drawn alone, a number is solid.
  indexed: boolean
  changes: boolean
  groups?: boolean
}

// label: the group's name, null for a row without groups.
type Group = { label: string | null; numbers: NumberView[] }

export default function NumberToggles({ numbers, lines, indexed, changes, groups = false, ...events }: Props) {
  const row = useRef<HTMLDivElement>(null)
  const ruler = useRef<HTMLDivElement>(null)
  const [fit, setFit] = useState(numbers.length)
  const [more, setMore] = useState(false)
  const full = Object.keys(lines).length >= MAX_DRAWN
  const shape = numbers.map((number) => `${number.key}:${number.value}:${lines[number.key] ?? "-"}:${number.change?.text ?? ""}`).join("|")
  const all = grouped(numbers, groups)

  // The ruler holds every group's label and toggle as they would look, out
  // of sight and clipped, so the row knows how many fit before it shows
  // them, and the page never scrolls sideways to a row it does not show.
  useLayoutEffect(() => {
    const box = row.current
    const sample = ruler.current
    if (!box || !sample) return undefined
    const place = () => {
      const widths = [...sample.children].map((child) => (child as HTMLElement).offsetWidth)
      const button = widths.pop() ?? 0
      let at = 0
      const measured = all.map((group) => ({ label: group.label ? widths[at++] ?? 0 : 0, toggles: group.numbers.map(() => widths[at++] ?? 0) }))
      setFit(fitting(measured, button, box.clientWidth, GAP, groups ? GROUP_GAP : GAP))
    }
    place()
    const observer = new ResizeObserver(place)
    observer.observe(box)
    return () => observer.disconnect()
  }, [shape, groups])

  const head = numbers.slice(0, fit)
  const tail = numbers.slice(fit)
  const tailDrawn = tail.some((number) => lines[number.key] !== undefined)
  const open = tail.length > 0 && (more || tailDrawn)
  const line = (number: NumberView) => (lines[number.key] === undefined ? null : lineOf(lines, number.key, indexed))
  const toggle = (number: NumberView) => <Toggle key={number.key} number={number} line={line(number)} full={full} changes={changes} events={events} />
  const gaps = groups ? "gap-x-4 gap-y-2" : "gap-2"

  return (
    <div className="min-w-0 flex-[1_1_480px]">
      <div ref={row} className={`relative flex min-w-0 flex-wrap items-center ${gaps}`} role="group" aria-label="Numbers on the chart">
        {grouped(head, groups).map((group) => <Grouped key={group.label ?? "all"} group={group}>{group.numbers.map(toggle)}</Grouped>)}
        {tail.length > 0 && !(open && tailDrawn) && (
          <button type="button" className="h-11 rounded-control px-3 text-[13px] font-bold text-accent-ink" aria-expanded={open} onClick={() => setMore(!open)}>
            {open ? "Show fewer" : `+ ${tail.length} more`}
          </button>
        )}
        <div className="pointer-events-none invisible absolute inset-x-0 top-0 h-0 overflow-hidden" aria-hidden="true" inert>
          <div ref={ruler} className="flex w-max gap-2">
            {all.flatMap((group) => [
              ...(group.label ? [<Label key={`label-${group.label}`} label={group.label} />] : []),
              ...group.numbers.map((number) => <Toggle key={number.key} number={number} line={line(number)} full={full} changes={changes} />),
            ])}
            <span className="h-11 px-3 text-[13px] font-bold whitespace-nowrap">+ {numbers.length} more</span>
          </div>
        </div>
      </div>
      {open && (
        <div className={`mt-2.5 flex flex-wrap items-center ${gaps}`} role="group" aria-label="More numbers">
          {grouped(tail, groups).map((group) => <Grouped key={group.label ?? "all"} group={group}>{group.numbers.map(toggle)}</Grouped>)}
        </div>
      )}
    </div>
  )
}

// The numbers in a run of their groups, in their order; one group with no
// name for a row without groups.
function grouped(numbers: NumberView[], groups: boolean): Group[] {
  if (!groups) return numbers.length > 0 ? [{ label: null, numbers }] : []
  return numbers.reduce<Group[]>((all, number) => {
    const last = all[all.length - 1]
    if (last && last.label === number.group) last.numbers.push(number)
    else all.push({ label: number.group, numbers: [number] })
    return all
  }, [])
}

function Grouped({ group, children }: { group: Group; children: ReactNode }) {
  if (!group.label) return <>{children}</>
  return (
    <div role="group" aria-label={group.label} className="inline-flex min-w-0 flex-wrap items-center gap-2">
      <Label label={group.label} />
      {children}
    </div>
  )
}

function Label({ label }: { label: string }) {
  return <span className="pr-0.5 text-xs font-bold whitespace-nowrap text-ink-3" aria-hidden="true">{label}</span>
}

// line: the line it wears while drawn, null while not.
function Toggle({ number, line, full, changes, events }: { number: NumberView; line: number | null; full: boolean; changes: boolean; events?: NumberEvents }) {
  const drawn = line !== null
  const look = drawn ? "border-ink bg-surface text-ink" : full ? "border-dashed border-line text-ink-3" : "border-line text-ink-2 hover:border-ink-3"
  return (
    <button type="button" aria-pressed={drawn} title={!drawn && full ? "Switch a number off first" : undefined}
            className={`relative inline-flex h-11 items-center gap-[7px] whitespace-nowrap rounded-control border-[1.5px] px-[13px] max-md:gap-1.5 max-md:px-[11px] ${look}`}
            onClick={() => events?.toggle(number.key)}
            onPointerEnter={(event) => { events?.warm(number.key); if (event.pointerType === "mouse") events?.focus(number.key) }}
            onPointerLeave={() => events?.focus(null)}
            onFocus={() => { events?.warm(number.key); events?.focus(number.key) }} onBlur={() => events?.focus(null)}>
      {drawn ? <LineKey line={line} /> : <span className="w-3 text-center font-bold text-ink-3" aria-hidden="true">+</span>}
      <span className="text-[13px] font-bold">{number.label}</span>
      <span className="os-num text-base tracking-[-.02em]">{number.value}</span>
      {changes && number.change?.arrow && <ChangeText change={number.change} />}
      <span className={`absolute inset-x-3 bottom-[5px] flex h-[3px] gap-0.5 ${drawn ? "" : "opacity-45"}`} aria-hidden="true">
        {number.split.map((part) => (
          <span key={part.repo} className={`${projectClass(part.rank)} min-w-[3px] rounded-[2px] bg-(--project)`} style={{ flex: `${part.value} 1 0` }} />
        ))}
      </span>
    </button>
  )
}

// Only the arrow wears the change's colour.
function ChangeText({ change }: { change: Change }) {
  const tone = change.up === null ? "" : change.up ? "text-up" : "text-down"
  return <span className="text-[11px] font-bold text-ink-2 max-md:hidden"><span className={tone}>{change.arrow}</span> {change.text}</span>
}
