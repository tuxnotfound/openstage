import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test } from "vitest"
import { Tip, type ProjectNumber } from "../../app/javascript/charts/filter/CompareChart"
import type { CompareChartView } from "../../app/javascript/charts/types"

// A point of a chart that draws site visits alone, as the server sends it
// (CompareChartSerializer): each project's site visitors beside its site
// visits where it shows them, a dash where it does not.
const tips = [{ key: "visits", label: "Site visits", line: true }, { key: "site_visitors", label: "Site visitors", line: false }]
const column = {
  left: 90, width: 10, mark: 50, title: "Wed, Oct 28 · 7-day average",
  rows: [{ key: "me/app", name: "app", colorClass: "os-project-1", values: ["12.4", "3.1"] }, { key: "me/lib", name: "lib", colorClass: "os-project-2", values: ["2.0", "–"] }],
}
const chart = (view: Partial<CompareChartView> = {}): CompareChartView => ({
  paths: [], ticks: [], columns: [column], heads: ["visits"], tips, axis: [], ariaLabel: "", note: "", noteParts: null, none: "Nothing this day", indexed: false, ...view,
})

function tip(view: CompareChartView, hidden?: (each: ProjectNumber) => boolean): string {
  return renderToStaticMarkup(<Tip chart={view} column={view.columns[0] ?? column} lines={{ visits: 0 }} x={95} hidden={hidden} />)
}

// Each head as [its name, whether it wears its line's sample, whether its
// name shows on a phone].
function heads(html: string): [string, boolean, boolean][] {
  return [...html.matchAll(/<span class="inline-flex[^"]*">(<svg[^]*?<\/svg>)?<span( class="max-md:sr-only")?>([^<]*)<\/span><\/span>/g)]
    .map(([, sample, phoneless, name = ""]) => [name, sample !== undefined, phoneless === undefined])
}

// Every value, row by row.
function values(html: string): string[] {
  return [...html.matchAll(/tabular-nums">([^<]*)<\/span>/g)].map(([, value = ""]) => value)
}

describe("the chart's tooltip", () => {
  test("heads a column per tip: a number drawn with its line's sample, and the number beside it by its name alone, on a phone too", () => {
    const html = tip(chart())

    expect(heads(html)).toEqual([["Site visits", true, false], ["Site visitors", false, true]])
    expect(html).toContain("repeat(2, max-content)")
    expect(values(html)).toEqual(["12.4", "3.1", "2.0", "–"])
  })

  test("has no heads with one column", () => {
    const one = { ...column, rows: [{ key: "me/app", name: "app", colorClass: "os-project-1", values: ["3"] }] }
    const html = tip(chart({ columns: [one], heads: ["commits"], tips: [{ key: "commits", label: "Commits", line: true }] }))

    expect(heads(html)).toEqual([])
    expect(html).not.toContain("Commits")
    expect(values(html)).toEqual(["3"])
  })

  test("blanks a project's value at once while the dashboard saves its switch", () => {
    const html = tip(chart(), (each) => each.key === "me/app" && each.number === "site_visitors")

    expect(values(html)).toEqual(["12.4", "–", "2.0", "–"])
  })

  test("blanks a project's value beside a number with its own, whose line is gone", () => {
    const html = tip(chart(), (each) => each.key === "me/app" && each.number === "visits")

    expect(values(html)).toEqual(["–", "–", "2.0", "–"])
  })
})
