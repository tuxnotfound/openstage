import type { ProgressRange } from "../types"
import type { Target } from "../useView"

// The window, at the top right of what it scopes: the same four on every
// chart page. Each asks for its view on click and warms it when the pointer
// or focus reaches it.

const RANGES: [ProgressRange, string][] = [["30d", "30 days"], ["90d", "90 days"], ["12m", "12 months"], ["all", "All time"]]

export default function WindowPills({ range, target, className = "" }: { range: ProgressRange; target: (range: ProgressRange) => Target; className?: string }) {
  return (
    <div className={`os-pills ${className}`} role="group" aria-label="Time range">
      {RANGES.map(([value, label]) => {
        const to = target(value)
        return (
          <button key={value} type="button" className="os-pill max-md:px-2.5" aria-pressed={value === range}
                  onClick={to.go} onPointerEnter={to.warm} onFocus={to.warm}>{label}</button>
        )
      })}
    </div>
  )
}
