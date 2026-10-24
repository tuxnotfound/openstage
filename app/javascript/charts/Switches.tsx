import { projectClass } from "./LineChart"
import type { Rank } from "./types"

// The projects or pages a chart can show, each in its colour with a switch
// that takes it in or out of view: the chart's legend and its filter at once.
// One always stays in view, so the last switch on cannot be turned off.

// A view to show on click, and to warm when the pointer or focus reaches it.
export type Target = { go: () => void; warm: () => void }
// value: what the row counts in the window, shown beside its name.
export type SwitchItem = { key: string; name: string; rank: Rank; on: boolean; value?: string | null }

type Props = {
  label: string
  items: SwitchItem[]
  target: (key: string) => Target
  // Every item back in view; null when every item already is.
  all: Target | null
}

export default function Switches({ label, items, target, all }: Props) {
  const lastOn = items.filter((item) => item.on).length === 1

  return (
    <div role="group" aria-label={label} className="min-w-0">
      <div className="os-between">
        <h2 className="os-label">{label}</h2>
        {all && <button type="button" className="os-link text-[13px]" onClick={all.go} onPointerEnter={all.warm} onFocus={all.warm}>Show all</button>}
      </div>
      <ul className="mt-1.5">
        {items.map((item) => {
          const switched = target(item.key)
          const locked = item.on && lastOn
          return (
            <li key={item.key} className="os-row flex items-center gap-2.5 py-2">
              <span className={`os-dot ${projectClass(item.rank)} bg-(--project) ${item.on ? "" : "opacity-40"}`} aria-hidden="true" />
              <span className={`min-w-0 flex-1 truncate font-bold ${item.on ? "" : "text-ink-3"}`}>{item.name}</span>
              {item.value && <span className="os-xs os-muted shrink-0">{item.value}</span>}
              <button type="button" role="switch" aria-checked={item.on} aria-label={`Show ${item.name} in the chart`} className="os-switch"
                      disabled={locked} onClick={switched.go} onPointerEnter={switched.warm} onFocus={switched.warm} />
            </li>
          )
        })}
      </ul>
    </div>
  )
}
