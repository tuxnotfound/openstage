import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test } from "vitest"
import ProjectsTable, { type CellSwitches, type RowTargets } from "../../app/javascript/charts/filter/ProjectsTable"
import type { TableCell, TableRow } from "../../app/javascript/charts/types"

// The dashboard's site visits cell as the island draws it, the same three
// ways charts/_table draws it first (dashboard_projects_spec.rb).
const siteRow = (id: number) => `/projects/${id}/edit?site=open#site-visits`
const visits = (cell: Partial<TableCell>): TableCell => ({ key: "visits", value: null, shown: false, pick: null, link: null, change: null, ...cell })
const row = (name: string, cell: TableCell): TableRow =>
  ({ key: `me/${name}`, name, colorClass: "os-project-1", on: true, drawable: true, cells: [cell], edit: null, page: null, switch: "/projects/1/numbers" })

const target = { go: () => {}, warm: () => {} }
const rows: RowTargets = { box: () => target, only: () => target, all: null, refuse: () => {}, focus: () => {} }
const switches: CellSwitches = { pick: (_, cell) => cell.pick, shown: (_, cell) => cell.shown, flip: () => {} }

// Each row's site visits cell, as markup with its quotes back.
function cells(...tableRows: TableRow[]): Record<string, string> {
  const html = renderToStaticMarkup(
    <ProjectsTable table={{ columns: [{ key: "visits", label: "Site visits", word: "site visits" }], rows: tableRows }} drawn={["visits"]}
                   lines={{ visits: 0 }} indexed={false} words="last 90 days" focused={null} rows={rows} switches={switches} />,
  ).replaceAll("&#x27;", "'")
  return Object.fromEntries(tableRows.map((each) => {
    const start = html.indexOf(`data-chart-row="${each.key}"`)
    const cell = html.slice(html.indexOf("<td", html.indexOf("<td", start) + 1), html.indexOf("</tr>", start))
    return [each.name, cell]
  }))
}

describe("the dashboard's site visits cell", () => {
  test("has its value and switch where site visits count", () => {
    const { lunchbox } = cells(row("lunchbox", visits({ value: "90", shown: true, pick: true })))

    expect(lunchbox).toContain(">90</span>")
    expect(lunchbox).toContain('role="switch" aria-checked="true"')
    expect(lunchbox).not.toContain("<a ")
  })

  test("says Paused, with the value in grey and no switch, where Free counts another project", () => {
    const { tidepool } = cells(row("tidepool", visits({ value: "90", link: { kind: "paused", path: siteRow(2) } })))

    expect(tidepool).toMatch(/text-ink-3 font-medium">90<\/span>/)
    expect(tidepool).toContain(`<a href="${siteRow(2)}" aria-label="See why tidepool's site visits are paused"`)
    expect(tidepool).toContain(">Paused</a>")
    expect(tidepool).not.toContain('role="switch"')
  })

  test("says Set up where they count none, after the value only while the window has any", () => {
    const { quiet, fresh } = cells(row("quiet", visits({ value: "12", link: { kind: "set_up", path: siteRow(3) } })),
                                   row("fresh", visits({ link: { kind: "set_up", path: siteRow(4) } })))

    expect(quiet).toContain(">12</span>")
    expect(quiet).toContain(`<a href="${siteRow(3)}" aria-label="Set up quiet's site visits"`)
    expect(fresh).not.toContain("os-num")
    expect(fresh).toContain(">Set up</a>")
    expect([quiet, fresh].join()).not.toContain('role="switch"')
  })
})

describe("a project past the tenth", () => {
  test("has no box and no colour, and keeps its value in grey", () => {
    const commits: TableCell = { key: "commits", value: "4", shown: true, pick: null, link: null, change: null }
    const quiet: TableRow = { key: "me/quiet", name: "quiet", colorClass: null, on: false, drawable: false, cells: [commits], edit: null, page: null, switch: null }
    const html = renderToStaticMarkup(
      <ProjectsTable table={{ columns: [{ key: "commits", label: "Commits", word: "commits" }], rows: [{ ...quiet, key: "me/app", name: "app", colorClass: "os-project-1", on: true, drawable: true }, quiet] }}
                     drawn={["commits"]} lines={{ commits: 0 }} indexed={false} words="last 90 days" focused={null} rows={rows} />,
    )
    const row = html.slice(html.indexOf('data-chart-row="me/quiet"'))

    expect(html.match(/type="checkbox"/g)).toHaveLength(1)
    expect(row).not.toContain("os-project")
    expect(row).not.toContain('type="checkbox"')
    expect(row).toMatch(/text-ink-3 ">4<\/span>/)
  })
})
