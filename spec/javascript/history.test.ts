import { describe, expect, test } from "vitest"
import { marked, markOf, ours, outside } from "../../app/javascript/charts/history"

const own = ["range", "show", "projects", "from", "to"]
const turbo = { turbo: { restorationIdentifier: "r1", restorationIndex: 3 } }

describe("an island's entries in the browser's history", () => {
  test("keep Turbo's state beside the island's mark", () => {
    const state = marked(turbo, { page: "a", url: "/api/progress/me?range=30d" })

    expect(state).toEqual({ ...turbo, chart: { page: "a", url: "/api/progress/me?range=30d" } })
    expect(markOf(state)).toEqual({ page: "a", url: "/api/progress/me?range=30d" })
    expect([markOf(null), markOf(turbo), markOf({ chart: { page: 1 } })]).toEqual([null, null, null])
  })

  test("read two addresses as one page while they differ only in the island's own params", () => {
    expect(outside("http://x.test/dashboard?range=90d&q=work&show=visits", own)).toBe(outside("http://x.test/dashboard?q=work", own))
    expect(outside("http://x.test/dashboard?q=work&from=2026-10-01&to=2026-10-02", own)).toBe("/dashboard?q=work")
    expect(outside("http://x.test/dashboard?q=work", own)).not.toBe(outside("http://x.test/dashboard?q=play", own))
  })

  test("are the island's to show only with its own mark, and the rest of the page where it left it", () => {
    const state = marked(turbo, { page: "a", url: "/api/v" })
    const here = "http://x.test/dashboard?q=work&range=2026-10-01..2026-10-02"

    expect(ours(state, "a", "http://x.test/dashboard?q=work", here, own)).toEqual({ page: "a", url: "/api/v" })
    expect(ours(state, "b", "http://x.test/dashboard?q=work", here, own)).toBeNull()
    expect(ours(state, "a", "http://x.test/dashboard?q=play", here, own)).toBeNull()
    expect(ours(turbo, "a", "http://x.test/dashboard?q=work", here, own)).toBeNull()
  })
})
