import { KEY_DASHES } from "./lines"

// A number's line as a short sample, in a toggle, a column's head or the
// tooltip's: solid, dotted or dashed by its place in the line order.
export default function LineKey({ line, className = "h-1.5 w-[22px]" }: { line: number; className?: string }) {
  return (
    <svg className={`${className} flex-none overflow-visible`} viewBox="0 0 22 6" aria-hidden="true">
      <line x1="3" y1="3" x2="19" y2="3" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeDasharray={KEY_DASHES[line] || undefined} />
    </svg>
  )
}
