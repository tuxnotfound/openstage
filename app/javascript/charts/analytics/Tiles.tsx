import type { Tile } from "../types"
import ChangeWords from "../filter/ChangeWords"
import LineKey from "../filter/LineKey"
import type { NumberEvents } from "../filter/NumberToggles"
import { MAX_DRAWN, lineOf, type Lines } from "../filter/lines"

// The numbers above an analytics tab's chart, a tile each, as many to a row
// as fit and two on a phone: its name, its total for the rows in view, its
// change, and a thin bar of how it splits across them in their colours. A
// number with lines of its own is a toggle, as the other chart pages' are:
// its line while drawn, a plus while not, and dashed while three are drawn.
// One that sits beside another draws no line, so it is a figure, with no
// border, and no button.

type Props = NumberEvents & {
  tiles: Tile[]
  lines: Lines
  // Whether the chart compares numbers; drawn alone, a number is solid.
  indexed: boolean
}

export default function Tiles({ tiles, lines, indexed, ...events }: Props) {
  const full = Object.keys(lines).length >= MAX_DRAWN
  return (
    <div className="grid grid-cols-[repeat(auto-fill,minmax(160px,1fr))] gap-2.5 max-[900px]:grid-cols-2" role="group" aria-label="Numbers on the chart">
      {tiles.map((tile) => (tile.figure
        ? <Figure key={tile.key} tile={tile} />
        : <Toggle key={tile.key} tile={tile} line={lines[tile.key] === undefined ? null : lineOf(lines, tile.key, indexed)} full={full} events={events} />))}
    </div>
  )
}

const TILE = "relative m-0 flex min-h-[88px] min-w-0 flex-col items-start gap-[5px] rounded-[14px] border-[1.5px] pt-[11px] pr-[13px] pb-[17px] text-left"

// line: the line it wears while drawn, null while not.
function Toggle({ tile, line, full, events }: { tile: Tile; line: number | null; full: boolean; events: NumberEvents }) {
  const drawn = line !== null
  const look = drawn ? "border-ink bg-surface text-ink" : full ? "border-dashed border-line text-ink-3" : "border-line text-ink-2 hover:border-ink-3"
  return (
    <button type="button" aria-pressed={drawn} title={!drawn && full ? "Switch a number off first" : undefined}
            className={`${TILE} cursor-pointer pl-[13px] transition-colors ${look}`}
            onClick={() => events.toggle(tile.key)}
            onPointerEnter={(event) => { events.warm(tile.key); if (event.pointerType === "mouse") events.focus(tile.key) }}
            onPointerLeave={() => events.focus(null)}
            onFocus={() => { events.warm(tile.key); events.focus(tile.key) }} onBlur={() => events.focus(null)}>
      <span className="flex max-w-full items-center gap-[7px] text-[13px] font-bold whitespace-nowrap">
        {drawn ? <LineKey line={line} /> : <span className="w-3 text-center font-bold text-ink-3" aria-hidden="true">+</span>}
        <span>{tile.label}</span>
      </span>
      <Inside tile={tile} ink={drawn} />
      <Split tile={tile} css={`left-[13px] ${drawn ? "" : "opacity-45"}`} />
    </button>
  )
}

function Figure({ tile }: { tile: Tile }) {
  return (
    <div className={`${TILE} border-transparent pl-1 text-ink-2`}>
      <span className="flex max-w-full items-center gap-[7px] text-[13px] font-bold whitespace-nowrap">{tile.label}</span>
      <Inside tile={tile} ink />
      <Split tile={tile} css="left-1" />
    </div>
  )
}

// Its value, in ink while drawn or a figure, then its change or what
// follows it.
function Inside({ tile, ink }: { tile: Tile; ink: boolean }) {
  return (
    <span className="flex max-w-full items-baseline gap-2 whitespace-nowrap">
      <span className={`font-display text-[27px] leading-[1.12] font-semibold tracking-[-.03em] max-[900px]:text-[23px] ${ink ? "text-ink" : "text-ink-2"}`}>{tile.value}</span>
      {tile.change?.arrow && <span className="text-xs font-bold whitespace-nowrap text-ink-2"><ChangeWords change={tile.change} /></span>}
      {tile.suffix && <span className="text-xs font-bold whitespace-nowrap text-ink-2">{tile.suffix}</span>}
    </span>
  )
}

// How it splits across the rows in view, each in its colour; the rows
// past the palette share one part with none.
function Split({ tile, css }: { tile: Tile; css: string }) {
  return (
    <span className={`absolute right-[13px] bottom-2 flex h-[3px] gap-0.5 ${css}`} aria-hidden="true">
      {tile.split.map((part) => (
        <span key={part.key} className={`min-w-[3px] rounded-[2px] ${part.colorClass ? `${part.colorClass} bg-(--project)` : ""}`} style={{ flex: `${part.value} 1 0` }} />
      ))}
    </span>
  )
}
