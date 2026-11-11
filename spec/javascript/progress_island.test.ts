import { describe, expect, test } from "vitest"
import { pendingCells, stillPending } from "../../app/javascript/charts/progress/ProgressIsland"
import type { TableCell, TableRow, TableView } from "../../app/javascript/charts/types"

// The dashboard's table as the server sends it once app's site visits are
// switched off: its site visitors, which sit beside them, have no switch.
const cell = (key: string, pick: boolean | null): TableCell => ({ key, value: "1", shown: pick === true, pick, link: null, change: null })
const table: TableView = {
  columns: [], stack: "md", more: null,
  rows: [{ key: "me/app", name: "app", colorClass: "os-project-1", on: true, drawable: true, edit: null, page: null, switch: "/projects/1/numbers",
           cells: [cell("commits", true), cell("visits", false), cell("site_visitors", null)] }],
}

describe("the dashboard's pending switches", () => {
  test("wait while the server says otherwise, and end once it agrees, no longer offers the switch or no longer lists the row", () => {
    const pending = { "me/app|commits": false, "me/app|visits": false, "me/app|site_visitors": true, "me/gone|commits": true }

    expect(stillPending(pending, table)).toEqual({ "me/app|commits": false })
    expect(stillPending(pending, null)).toEqual({})
  })
})

// The same table before the switch: app shows its commits, its site visits
// and the site visitors beside them, each switch on.
const app: TableRow = { key: "me/app", name: "app", colorClass: "os-project-1", on: true, drawable: true, edit: null, page: null, switch: "/projects/1/numbers",
                        cells: [cell("commits", true), cell("visits", true), cell("site_visitors", true)] }
const before: TableView = {
  columns: [{ key: "commits", label: "Commits", word: "commits", beside: null }, { key: "visits", label: "Site visits", word: "site visits", beside: null },
            { key: "site_visitors", label: "Site visitors", word: "site visitors", beside: "visits" }],
  rows: [app], stack: "md", more: null,
}

// Each of app's cells as [its switch, whether it reads shown] while some
// switches wait for their save.
function read(pending: Record<string, boolean>): [boolean | null, boolean][] {
  const { pick, shown } = pendingCells(pending, before)
  return app.cells.map((each) => [pick(app, each), shown(app, each)])
}

describe("the dashboard's cells while a switch saves", () => {
  test("read as their switch was flipped", () => {
    expect(read({ "me/app|commits": false })).toEqual([[false, false], [true, true], [true, true]])
  })

  test("read hidden, with no switch, while the number they sit beside saves off, as the server then sends them, and come back if that save fails", () => {
    expect(read({ "me/app|visits": false })).toEqual([[true, true], [false, false], [null, false]])
    expect(read({ "me/app|visits": false, "me/app|site_visitors": true })).toEqual([[true, true], [false, false], [null, false]])
    expect(read({})).toEqual([[true, true], [true, true], [true, true]])
  })
})
