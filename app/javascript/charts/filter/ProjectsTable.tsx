import type { CellLink, Change, TableCell, TableRow, TableView } from "../types"
import type { Target } from "../useView"
import ChangeWords from "./ChangeWords"
import LineKey from "./LineKey"
import { lineOf, type Lines } from "./lines"

// The rows under the chart, its key, as charts/_table renders them: a row
// per project (per page on analytics), a column per number, each cell the
// row's value over the window (on analytics with its change under it),
// drawn cells in ink. A builder's stage lists the projects with a colour
// and links to its list of the rest (more). A row's box, in its colour, draws it or not, Only
// shows it alone and Show all brings the rest back; the last row in view
// keeps its box, and a click says so. A project past the palette has no
// colour, so no box, and keeps its values in grey; a row with no box tells
// a screen reader it draws no line. Hovering or focusing a row brings its
// lines forward. On the dashboard (manage) a row also has Edit, whether
// the builder's page lists it and whether it is pinned there with a colour
// (Pin), and each cell the switch for what visitors
// see (its value grey while they do not), or Set up or Paused where site
// visits do not count; a project hidden from the page is in the dashboard's
// list of projects, not here. Each of the builder's switches is an eye (Eye), open while visitors
// see it on the stage. On a phone each row stacks, with only the numbers it counts, and
// below the width its columns need too (stack, the stacked variant). The
// name column takes what the numbers leave, and a long name wraps rather
// than widening the table. Only shows on hover, and always on a touch
// screen, where there is no hover to find it by. A table that is wider
// still, as very large numbers can make one, scrolls inside its panel, never
// the page.

export type RowTargets = {
  // A row's box; null when it is the last project in view.
  box: (key: string) => Target | null
  only: (key: string) => Target
  all: Target | null
  refuse: () => void
  focus: (key: string | null) => void
}

// The dashboard's switches, which answer at once and save in the background.
export type CellSwitches = {
  pick: (row: TableRow, cell: TableCell) => boolean | null
  shown: (row: TableRow, cell: TableCell) => boolean
  flip: (row: TableRow, cell: TableCell) => void
}

type Props = {
  table: TableView
  drawn: string[]
  lines: Lines
  indexed: boolean
  words: string
  // The project whose lines are forward, for its row's tint.
  focused: string | null
  rows: RowTargets
  switches?: CellSwitches
  // What a row is: "Projects", or "Pages" on analytics.
  label?: string
}

export default function ProjectsTable({ table, drawn, lines, indexed, words, focused, rows, switches, label = "Projects" }: Props) {
  if (table.rows.length === 0) {
    return <div className="mt-5"><p className="os-sm os-ink2">No repo has commits here yet. Your public repos appear once the first sync is done.</p></div>
  }
  const on = table.rows.filter((row) => row.on).length
  return (
    <>
      <div className="-mx-1 mt-5 overflow-x-auto px-1" data-chart-table data-stack={table.stack}>
        <table className="w-full border-collapse text-sm stacked:block">
          <caption className="sr-only">{label}: what the chart draws, and each number, {words}</caption>
          <thead className="stacked:block">
            <tr className="text-xs text-ink-3 stacked:flex">
              <th scope="col" className="w-full min-w-45 max-w-0 pt-1.5 pb-2 text-left font-bold stacked:max-w-none">
                <span className="flex items-center gap-3">
                  {label}
                  {rows.all && <button type="button" className="os-link inline-flex min-h-7 items-center rounded-md px-1.5 text-[13px] no-underline" onClick={rows.all.go} onPointerEnter={rows.all.warm} onFocus={rows.all.warm}>Show all</button>}
                </span>
              </th>
              {switches && <th scope="col" className="w-px whitespace-nowrap pt-1.5 pb-2 pl-[18px] text-right font-bold stacked:hidden">Your stage</th>}
              {table.columns.map((column) => (
                <th key={column.key} scope="col" className={`whitespace-nowrap pt-1.5 pb-2 pl-[18px] text-right font-bold stacked:hidden ${drawn.includes(column.key) ? "text-ink" : ""}`}>
                  <span className="inline-flex items-center gap-[7px]">
                    <span className={drawn.includes(column.key) ? "" : "invisible"}><LineKey line={lineOf(lines, column.key, indexed)} /></span>{column.label}
                  </span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="stacked:block">
            {table.rows.map((row) => (
              <Row key={row.key} row={row} table={table} drawn={drawn} alone={row.on && on === 1} hot={focused === row.key} rows={rows} switches={switches} />
            ))}
          </tbody>
        </table>
        {table.more && (
          <p className="border-t border-line pt-3">
            <a href={`#${table.more.anchor}`} className="os-link text-sm" data-turbo="false">{table.more.text} <span aria-hidden="true">↓</span></a>
          </p>
        )}
      </div>
    </>
  )
}

// A switch for what visitors see, as charts/_table draws it: an eye, open
// while they see it on the stage, struck through while only the builder
// does (.os-eye, by the switch's aria-checked), its title saying which and
// what a click does.
export function Eye() {
  return (
    <>
      <svg className="os-eye-open size-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
        <path strokeLinejoin="round" d="M2 12c1.6-4 5.4-7 10-7s8.4 3 10 7c-1.6 4-5.4 7-10 7s-8.4-3-10-7Z" /><circle cx="12" cy="12" r="3" />
      </svg>
      <svg className="os-eye-shut size-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
        <path strokeLinecap="round" strokeLinejoin="round" d={EYE_SHUT} />
      </svg>
    </>
  )
}

const EYE_SHUT = "M3 3l18 18M10.6 10.6a2 2 0 0 0 2.8 2.8M9.9 5.1A9.8 9.8 0 0 1 12 5c4.8 0 8.8 3.2 10 7a10.6 10.6 0 0 1-3 4.4M6.6 6.6A10.5 10.5 0 0 0 2 12c1.2 3.8 5.2 7 10 7 1.6 0 3.1-.3 4.4-.9"

// An eye's title: whether visitors see it, and what a click does.
export function eyeTitle(on: boolean): string {
  return on ? "Visitors see it on your stage. Click to hide it." : "Only you see it. Click to show it on your stage."
}

function Row({ row, table, drawn, alone, hot, rows, switches }: {
  row: TableRow; table: TableView; drawn: string[]; alone: boolean; hot: boolean; rows: RowTargets; switches?: CellSwitches
}) {
  const box = row.drawable ? rows.box(row.key) : null
  const only = row.drawable && !alone ? rows.only(row.key) : null
  const name = `wrap-anywhere font-bold ${row.drawable ? (row.on ? "" : "text-ink-2") : "font-semibold text-ink-3"}`
  return (
    <tr className={`group border-t border-line transition-colors stacked:grid stacked:grid-cols-3 stacked:gap-x-3 stacked:gap-y-2.5 stacked:py-3 ${hot ? "bg-surface" : ""}`}
        data-chart-row={row.key} onPointerEnter={(event) => { if (row.drawable && event.pointerType === "mouse") rows.focus(row.key) }}
        onPointerLeave={() => rows.focus(null)}>
      <th scope="row" className="min-w-45 max-w-0 py-2.5 text-left font-normal stacked:col-span-3 stacked:max-w-none stacked:py-0">
        <span className="flex min-w-0 items-center gap-2.5">
          {row.drawable ? (
            <label className="relative inline-flex min-h-7 min-w-0 cursor-pointer items-center gap-2.5">
              <input type="checkbox" className="peer absolute left-0 m-0 size-[18px] opacity-0" checked={row.on}
                     onChange={() => (box ? box.go() : rows.refuse())} onPointerEnter={box?.warm}
                     onFocus={() => { box?.warm(); rows.focus(row.key) }} onBlur={() => rows.focus(null)} />
              <span aria-hidden="true"
                    className={`${row.colorClass ?? ""} inline-flex size-[18px] flex-none items-center justify-center rounded-[5px] border-2 peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-accent ${row.on ? "border-(--project) bg-(--project) text-(--on-project)" : "border-ink-3"}`}>
                {row.on
                  ? <svg viewBox="0 0 12 12" className="size-3"><path d="M2.4 6.3l2.4 2.4 4.8-5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>
                  : <span className="size-2 rounded-[2px] bg-(--project)" />}
              </span>
              <span className={name}>{row.name}</span>
            </label>
          ) : <><span className={name}>{row.name}</span><span className="sr-only">, draws no line</span></>}
          {only && (
            <button type="button" aria-label={`Show only ${row.name}`} onClick={only.go} onPointerEnter={only.warm} onFocus={only.warm}
                    className="min-h-7 shrink-0 rounded-md px-1.5 py-0.5 text-[13px] font-bold text-accent-ink opacity-0 group-focus-within:opacity-100 group-hover:opacity-100 focus:opacity-100 stacked:opacity-100 pointer-coarse:opacity-100">Only</button>
          )}
          {row.edit && <a href={row.edit} className="os-btn2 ml-auto h-[30px] shrink-0 rounded-[9px] px-3 text-[13px]" aria-label={`Edit ${row.name}`}>Edit</a>}
        </span>
      </th>
      {switches && (
        <td className="whitespace-nowrap py-2.5 pl-[18px] text-right stacked:p-0 stacked:text-left">
          <span className="os-xs os-muted mb-1 hidden stacked:block">Your stage</span>
          {row.page && <PageSwitch name={row.name} page={row.page} />}
          {row.pin && <PinSwitch name={row.name} pin={row.pin} />}
        </td>
      )}
      {row.cells.map((cell) => {
        const column = table.columns.find((each) => each.key === cell.key)
        return (
          <td key={cell.key} className={`py-2.5 pl-[18px] text-right stacked:p-0 stacked:text-left ${cell.value === null && cell.link === null ? "stacked:hidden" : ""}`}>
            <span className="os-xs os-muted mb-1 hidden stacked:block">{column?.label}</span>
            <Cell row={row} cell={cell} word={column?.word ?? cell.key} drawn={drawn.includes(cell.key)} switches={switches} />
          </td>
        )
      })}
    </tr>
  )
}

// A cell's value, its change under it on analytics; where site visits do
// not count, Set up or Paused in the switch's place, after the value when
// the window has any.
function Cell({ row, cell, word, drawn, switches }: { row: TableRow; cell: TableCell; word: string; drawn: boolean; switches?: CellSwitches }) {
  const shown = switches ? switches.shown(row, cell) : cell.shown
  const pick = switches?.pick(row, cell) ?? null
  return (
    <span className="inline-flex items-center gap-2.5">
      {(cell.link === null || cell.value !== null) && (
        <span className="inline-block">
          <span className={`os-num text-[15px] tracking-[-.02em] ${row.on && shown && drawn ? "text-ink" : "text-ink-3"} ${shown ? "" : "font-medium"}`}>{cell.value ?? "–"}</span>
          {cell.change?.arrow && <ChangeLine change={cell.change} />}
        </span>
      )}
      {cell.link && <SiteLink link={cell.link} />}
      {switches && pick !== null && (
        <button type="button" role="switch" aria-checked={pick} aria-label={`Show ${word} for ${row.name}`} title={eyeTitle(pick)} className="os-eye"
                onClick={() => switches.flip(row, cell)}><Eye /></button>
      )}
    </span>
  )
}

// Its words are the server's, as charts/_table writes them.
function SiteLink({ link }: { link: CellLink }) {
  return (
    <a href={link.path} aria-label={link.label}
       className="inline-flex min-h-6 items-center text-[13px] font-bold text-accent-ink underline underline-offset-3">{link.text}</a>
  )
}

// A cell's change, under its value.
function ChangeLine({ change }: { change: Change }) {
  return <span className="mt-px block text-[11px] font-bold text-ink-2"><ChangeWords change={change} /></span>
}

// The fields a stage switch sends beside its own: the chart's view, as the
// page's address holds it, then the caller's (the list's view), as
// charts/_stage_switches writes them.
type Fields = [string, string][]

function Kept({ fields = [] }: { fields?: Fields }) {
  const view = new URLSearchParams(window.location.search)
  const chart: Fields = ["range", "show", "projects"].flatMap((key) => { const value = view.get(key); return value ? [[key, value] as [string, string]] : [] })
  return <>{[...chart, ...fields].map(([key, value]) => <input key={key} type="hidden" name={key} value={value} />)}</>
}

// GithubReposController switches it and sends the dashboard back, as the
// page reloads without its line.
export function PageSwitch({ name, page, fields }: { name: string; page: { on: boolean; path: string }; fields?: Fields }) {
  return (
    <form method="post" action={page.path} className="inline-flex align-middle" data-turbo="false">
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" value={csrfToken()} />
      <input type="hidden" name="included" value={String(!page.on)} />
      <Kept fields={fields} />
      <button type="submit" role="switch" aria-checked={page.on} aria-label={`Show ${name} on your stage`} title={eyeTitle(page.on)} className="os-eye">
        <Eye />
      </button>
    </form>
  )
}

// Projects::PinsController pins it or not and sends the dashboard back, as
// every colour on it moves. Its title is the server's (pin_title).
export function PinSwitch({ name, pin, fields }: { name: string; pin: NonNullable<TableRow["pin"]>; fields?: Fields }) {
  return (
    <form method="post" action={pin.path} className="ml-1 inline-flex align-middle" data-turbo="false">
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" value={csrfToken()} />
      <input type="hidden" name="pinned" value={String(!pin.on)} />
      <Kept fields={fields} />
      <button type="submit" role="switch" aria-checked={pin.on} aria-label={`Pin ${name} to your stage`} title={pin.title} className="os-eye os-pin">
        <Pin />
      </button>
    </form>
  )
}

// A project's pin, as charts/_pin draws it: its head filled while it is
// pinned (.os-pin, by the switch's aria-checked).
export function Pin() {
  return (
    <svg className="size-[18px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path className="os-pin-head" d="M10 3h4v6l3 4H7l3-4Z" /><path d="M8.5 3h7M12 13v8" />
    </svg>
  )
}

export function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""
}
