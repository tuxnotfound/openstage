import type { Change, TableCell, TableRow, TableView } from "../types"
import type { Target } from "../useView"
import ChangeWords from "./ChangeWords"
import LineKey from "./LineKey"
import { lineOf, projectClass, type Lines } from "./lines"

// The rows under the chart, its key, as charts/_table renders them: a row
// per project (per page on analytics), a column per number, each cell the
// row's value over the window (on analytics with its change under it),
// drawn cells in ink. A row's box, in its colour, draws it or not, Only
// shows it alone and Show all brings the rest back; the last row in view
// keeps its box, and a click says so. Hovering or focusing a row brings its
// lines forward. On the dashboard (manage) a row also has Edit and whether
// the builder's page lists it, and each cell the switch for what visitors
// see (its value grey while they do not), or Set up; a project hidden from
// the page comes last, with no box. On a phone each row stacks, with only
// the numbers it counts. Only shows on hover, and always on a touch screen,
// where there is no hover to find it by.

export type RowTargets = {
  // A row's box; null when it is the last project in view.
  box: (repo: string) => Target | null
  only: (repo: string) => Target
  all: Target | null
  refuse: () => void
  focus: (repo: string | null) => void
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
    <div className="mt-5" data-chart-table>
      <table className="w-full border-collapse text-sm max-md:block">
        <caption className="sr-only">{label}: what the chart draws, and each number over the {words}</caption>
        <thead className="max-md:block">
          <tr className="text-xs text-ink-3 max-md:flex">
            <th scope="col" className="w-full pt-1.5 pb-2 text-left font-bold">
              <span className="flex items-center gap-3">
                {label}
                {rows.all && <button type="button" className="os-link inline-flex min-h-7 items-center rounded-md px-1.5 text-[13px] no-underline" onClick={rows.all.go} onPointerEnter={rows.all.warm} onFocus={rows.all.warm}>Show all</button>}
              </span>
            </th>
            {switches && <th scope="col" className="w-px whitespace-nowrap pt-1.5 pb-2 pl-[18px] text-right font-bold max-md:hidden">Your page</th>}
            {table.columns.map((column) => (
              <th key={column.key} scope="col" className={`whitespace-nowrap pt-1.5 pb-2 pl-[18px] text-right font-bold max-md:hidden ${drawn.includes(column.key) ? "text-ink" : ""}`}>
                <span className="inline-flex items-center gap-[7px]">
                  <span className={drawn.includes(column.key) ? "" : "invisible"}><LineKey line={lineOf(lines, column.key, indexed)} /></span>{column.label}
                </span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="max-md:block">
          {table.rows.map((row) => (
            <Row key={row.repo} row={row} table={table} drawn={drawn} alone={row.on && on === 1} hot={focused === row.repo} rows={rows} switches={switches} />
          ))}
        </tbody>
      </table>
    </div>
  )
}

function Row({ row, table, drawn, alone, hot, rows, switches }: {
  row: TableRow; table: TableView; drawn: string[]; alone: boolean; hot: boolean; rows: RowTargets; switches?: CellSwitches
}) {
  const box = row.drawable ? rows.box(row.repo) : null
  const only = row.drawable && !alone ? rows.only(row.repo) : null
  const name = `truncate font-bold ${row.drawable ? (row.on ? "" : "text-ink-2") : "font-semibold text-ink-3"}`
  return (
    <tr className={`group border-t border-line transition-colors max-md:grid max-md:grid-cols-3 max-md:gap-x-3 max-md:gap-y-2.5 max-md:py-3 ${hot ? "bg-surface" : ""}`}
        data-chart-row={row.repo} onPointerEnter={(event) => { if (row.drawable && event.pointerType === "mouse") rows.focus(row.repo) }}
        onPointerLeave={() => rows.focus(null)}>
      <th scope="row" className="py-2.5 text-left font-normal max-md:col-span-3 max-md:py-0">
        <span className="flex min-w-0 items-center gap-2.5">
          {row.drawable ? (
            <label className="relative inline-flex min-h-7 min-w-0 cursor-pointer items-center gap-2.5">
              <input type="checkbox" className="peer absolute left-0 m-0 size-[18px] opacity-0" checked={row.on}
                     onChange={() => (box ? box.go() : rows.refuse())} onPointerEnter={box?.warm}
                     onFocus={() => { box?.warm(); rows.focus(row.repo) }} onBlur={() => rows.focus(null)} />
              <span aria-hidden="true"
                    className={`${projectClass(row.rank)} inline-flex size-[18px] flex-none items-center justify-center rounded-[5px] border-2 peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-accent ${row.on ? "border-(--project) bg-(--project) text-(--on-project)" : "border-ink-3"}`}>
                {row.on
                  ? <svg viewBox="0 0 12 12" className="size-3"><path d="M2.4 6.3l2.4 2.4 4.8-5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /></svg>
                  : <span className="size-2 rounded-[2px] bg-(--project)" />}
              </span>
              <span className={name}>{row.name}</span>
            </label>
          ) : <span className={name}>{row.name}</span>}
          {only && (
            <button type="button" aria-label={`Show only ${row.name}`} onClick={only.go} onPointerEnter={only.warm} onFocus={only.warm}
                    className="min-h-7 shrink-0 rounded-md px-1.5 py-0.5 text-[13px] font-bold text-accent-ink opacity-0 group-focus-within:opacity-100 group-hover:opacity-100 focus:opacity-100 max-md:opacity-100 pointer-coarse:opacity-100">Only</button>
          )}
          {row.edit && <a href={row.edit} className="os-btn2 ml-auto h-[30px] shrink-0 rounded-[9px] px-3 text-[13px]" aria-label={`Edit ${row.name}`}>Edit</a>}
        </span>
      </th>
      {switches && (
        <td className="py-2.5 pl-[18px] text-right max-md:p-0 max-md:text-left">
          <span className="os-xs os-muted mb-1 block md:hidden">Your page</span>
          {row.page && <PageSwitch row={row} page={row.page} />}
        </td>
      )}
      {row.cells.map((cell) => {
        const column = table.columns.find((each) => each.key === cell.key)
        return (
          <td key={cell.key} className={`py-2.5 pl-[18px] text-right max-md:p-0 max-md:text-left ${cell.value === null && cell.setup === null ? "max-md:hidden" : ""}`}>
            <span className="os-xs os-muted mb-1 block md:hidden">{column?.label}</span>
            <Cell row={row} cell={cell} word={column?.word ?? cell.key} drawn={drawn.includes(cell.key)} switches={switches} />
          </td>
        )
      })}
    </tr>
  )
}

function Cell({ row, cell, word, drawn, switches }: { row: TableRow; cell: TableCell; word: string; drawn: boolean; switches?: CellSwitches }) {
  if (cell.setup) {
    return (
      <a href={cell.setup} aria-label={`Set up ${row.name}'s site visits`}
         className="inline-flex min-h-6 items-center text-[13px] font-bold text-accent-ink underline underline-offset-3">Set up</a>
    )
  }
  const shown = switches ? switches.shown(row, cell) : cell.shown
  const pick = switches?.pick(row, cell) ?? null
  return (
    <span className="inline-flex items-center gap-2.5">
      <span className="inline-block">
        <span className={`os-num text-[15px] tracking-[-.02em] ${row.on && shown && drawn ? "text-ink" : "text-ink-3"} ${shown ? "" : "font-medium"}`}>{cell.value ?? "–"}</span>
        {cell.change?.arrow && <ChangeLine change={cell.change} />}
      </span>
      {switches && pick !== null && (
        <button type="button" role="switch" aria-checked={pick} aria-label={`Show ${word} for ${row.name}`} className="os-switch"
                onClick={() => switches.flip(row, cell)} />
      )}
    </span>
  )
}

// A cell's change, under its value.
function ChangeLine({ change }: { change: Change }) {
  return <span className="mt-px block text-[11px] font-bold text-ink-2"><ChangeWords change={change} /></span>
}

// GithubReposController switches it and sends the dashboard back, as the
// page reloads without its line.
function PageSwitch({ row, page }: { row: TableRow; page: { on: boolean; path: string } }) {
  const view = new URLSearchParams(window.location.search)
  return (
    <form method="post" action={page.path} className="inline-flex" data-turbo="false">
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" value={csrfToken()} />
      <input type="hidden" name="included" value={String(!page.on)} />
      {["range", "show", "projects"].map((key) => view.get(key) && <input key={key} type="hidden" name={key} value={view.get(key) ?? ""} />)}
      <button type="submit" role="switch" aria-checked={page.on} aria-label={`Show ${row.name} on your page`} className="os-switch" />
    </form>
  )
}

export function csrfToken(): string {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""
}
