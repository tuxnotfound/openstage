import { describe, expect, test } from "vitest"
import { apiUrl, boxed, fitting, lineOf, lineOrder, linesFrom, noteOf, pageUrl, pathTops, reconcile, sentence, tipLeft, toggled, within } from "../../app/javascript/charts/filter/lines"
import type { CompareChartView, NumberView } from "../../app/javascript/charts/types"

const number = (key: string, label: string): NumberView => ({ key, label, word: label.toLowerCase(), group: "On GitHub", value: "1", split: [], change: null })
const numbers = [number("commits", "Commits"), number("visits", "Site visits"), number("stars", "Stars")]

describe("the lines of the numbers drawn", () => {
  test("follow the order the page names them in", () => {
    expect(linesFrom(["visits", "commits"])).toEqual({ visits: 0, commits: 1 })
    expect(lineOrder({ commits: 2, visits: 0 })).toEqual(["visits", "commits"])
  })

  test("keep their own while drawn, and a new number takes the first free line", () => {
    const after = toggled({ commits: 0, visits: 1 }, "commits", "commits")
    expect(after).toEqual({ lines: { visits: 1 } })

    expect(toggled({ visits: 1 }, "stars", "stars")).toEqual({ lines: { visits: 1, stars: 0 } })
  })

  test("keep the last number drawn, and three at most, saying so", () => {
    expect(toggled({ visits: 1 }, "visits", "site visits")).toEqual({ notice: "The chart keeps at least one number." })
    expect(toggled({ commits: 0, visits: 1, stars: 2 }, "mrr", "MRR")).toEqual({ notice: "The chart draws three numbers at most. Switch one off to draw MRR." })
  })

  test("follow the numbers the server drew, a new one taking a free line", () => {
    expect(reconcile({ commits: 0, visits: 1 }, ["visits"])).toEqual({ visits: 1 })
    expect(reconcile({ visits: 1 }, ["commits", "visits"])).toEqual({ visits: 1, commits: 0 })
  })

  test("of the numbers asked for are those the page can draw, each keeping its own", () => {
    expect(within({ commits: 0, visits: 1 }, ["commits", "stars"])).toEqual({ commits: 0 })
  })

  test("are solid for a number drawn alone on its own axis", () => {
    expect(lineOf({ visits: 1 }, "visits", false)).toBe(0)
    expect(lineOf({ visits: 1 }, "visits", true)).toBe(1)
  })
})

describe("the note under a chart that compares numbers", () => {
  const chart = {
    indexed: true, heads: ["commits", "visits"], note: "Commits solid and site visits dotted, as the server drew them.",
    noteParts: { before: "7-day averages. ", after: ", each against its own peak in the window; 100% is 3 commits a day and 40 site visits a day." },
  } as CompareChartView

  test("names each line by this page's own line order", () => {
    expect(noteOf(chart, numbers, { visits: 0, commits: 2 }))
      .toBe("7-day averages. Commits dashed and site visits solid, each against its own peak in the window; 100% is 3 commits a day and 40 site visits a day.")
  })

  test("is the server's when the chart draws one number", () => {
    expect(noteOf({ ...chart, indexed: false, noteParts: null }, numbers, {})).toBe(chart.note)
  })

  test("joins words as the app writes them", () => {
    expect([sentence(["a"]), sentence(["a", "b"]), sentence(["a", "b", "c"])]).toEqual(["a", "a and b", "a, b and c"])
  })
})

describe("a line at a point", () => {
  test("stands where the server's path put it, in percent from the top", () => {
    expect(pathTops("M0 280 L500 140 L1000 28")).toEqual([100, 50, 10])
  })
})

describe("the tooltip's box", () => {
  test("sits beside the point, on its roomier side, while it fits", () => {
    expect(tipLeft(20, 200, 1000)).toBe(214)
    expect(tipLeft(80, 200, 1000)).toBe(586)
  })

  test("stays inside the chart, against its nearer edge, when the point leaves too little room", () => {
    // A phone's chart, 322 px wide, and a box of 300: no side has room.
    expect(tipLeft(55, 300, 322)).toBe(4)
    expect(tipLeft(45, 300, 322)).toBe(18)
    expect(tipLeft(100, 120, 322)).toBe(188)
  })
})

describe("the row of number toggles", () => {
  const row = (...toggles: number[]) => [{ label: 0, toggles }]

  test("holds every toggle that fits, and folds the rest behind the more button", () => {
    expect(fitting(row(100, 100, 100), 60, 400, 8)).toBe(3)
    expect(fitting(row(100, 100, 100, 100), 60, 400, 8)).toBe(3)
    expect(fitting(row(300, 100), 60, 200, 8)).toBe(1)
  })

  test("folds whole groups, each with its label, so a group never splits across the rows", () => {
    const groups = [{ label: 60, toggles: [150] }, { label: 100, toggles: [160] }, { label: 90, toggles: [120, 120, 120] }]
    // 218 + 16 + 268 + 16 + 474 = 992 fits a row of 1000 whole.
    expect(fitting(groups, 80, 1000, 8, 16)).toBe(5)
    // In 900 the last group folds whole, though one of its toggles would fit.
    expect(fitting(groups, 80, 900, 8, 16)).toBe(2)
  })

  test("fits the first group's toggles one by one when not even it fits", () => {
    expect(fitting([{ label: 60, toggles: [150, 150, 150] }, { label: 90, toggles: [120] }], 80, 400, 8, 16)).toBe(1)
  })

  test("wraps on a phone, folding only what does not fit its lines", () => {
    // Analytics on a phone: On GitHub and On your websites take a line each,
    // the more button the third, and On Openstage folds whole.
    const analytics = [{ label: 65, toggles: [150] }, { label: 105, toggles: [175] }, { label: 85, toggles: [125, 110, 135] }]
    expect(fitting(analytics, 85, 326, 8, 16)).toBe(1)
    expect(fitting(analytics, 85, 326, 8, 16, 3)).toBe(2)
    // A row without groups wraps toggle by toggle.
    expect(fitting(row(150, 175, 160, 140), 80, 300, 8, 8, 3)).toBe(3)
    expect(fitting(row(150, 175, 160), 80, 300, 8, 8, 3)).toBe(3)
  })
})

describe("a row's box", () => {
  const all = ["me/a", "me/b", "me/c"]

  test("takes its row out of view, or puts it back, in the table's order", () => {
    expect(boxed("me/b", [], all)).toEqual(["me/a", "me/c"])
    expect(boxed("me/c", ["me/a"], all)).toEqual(["me/a", "me/c"])
  })

  test("names no rows once every one is back in view, and keeps the last one", () => {
    expect(boxed("me/b", ["me/a", "me/c"], all)).toEqual([])
    expect(boxed("me/a", ["me/a"], all)).toBeNull()
  })
})

describe("a view's addresses", () => {
  test("ask the API in the pages' order, whatever the line order", () => {
    const place = { range: "30d", show: ["visits", "commits"], projects: ["me/app"] }
    expect(apiUrl("/api/progress/me?dashboard=1", place, ["commits", "visits"]))
      .toBe("/api/progress/me?dashboard=1&range=30d&show=commits%2Cvisits&projects=me%2Fapp")
  })

  test("leave the page's defaults out of its URL and keep its other params", () => {
    const defaults = { range: "12m", show: ["commits", "visits"] }
    expect(pageUrl("http://x.test/me?repo%5B%5D=me%2Fapp&entry=4#top", { range: "12m", show: ["commits", "visits"], projects: [] }, defaults, { projects: true, dropped: ["repo", "repo[]"] }))
      .toBe("/me?entry=4#top")
    expect(pageUrl("http://x.test/dashboard?q=work&repo=me%2Fapp", { range: "30d", show: ["visits", "commits"], projects: ["me/app", "me/lib"] }, defaults, { projects: true, dropped: [] }))
      .toBe("/dashboard?q=work&repo=me/app&range=30d&show=visits,commits&projects=me/app,me/lib")
  })

  test("drop analytics' old params once a view names the same", () => {
    const place = { range: "90d", show: ["views"], projects: ["page", "me/app"] }
    expect(pageUrl("http://x.test/analytics?metric=site&pages%5B%5D=me%2Fapp", place, { range: "30d", show: ["commits"] }, { projects: true, dropped: ["pages", "pages[]", "metric"] }))
      .toBe("/analytics?range=90d&show=views&projects=page,me/app")
  })
})
