import { describe, expect, test } from "vitest"
import { stillPending } from "../../app/javascript/charts/progress/ProgressIsland"
import type { TableCell, TableView } from "../../app/javascript/charts/types"

// The dashboard's table as the server sends it once app's site visits are
// switched off: its site visitors, which sit beside them, have no switch.
const cell = (key: string, pick: boolean | null): TableCell => ({ key, value: "1", shown: pick === true, pick, link: null, change: null })
const table: TableView = {
  columns: [], stack: "md",
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
