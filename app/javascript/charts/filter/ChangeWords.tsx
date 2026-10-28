import type { Change } from "../types"

// A change's arrow and percent, as the pages write them: only the arrow
// wears the colour, and a screen reader hears its direction as a word
// rather than the arrow's shape.
export default function ChangeWords({ change }: { change: Change }) {
  const tone = change.up === null ? "" : change.up ? "text-up" : "text-down"
  const way = change.up === null ? null : change.up ? "up" : "down"
  return <><span className={tone} aria-hidden="true">{change.arrow}</span>{way && <span className="sr-only">{way}</span>} {change.text}</>
}
