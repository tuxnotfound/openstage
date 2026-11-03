import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test } from "vitest"
import Mark, { entriesHref, type Lead } from "../../app/javascript/charts/filter/Marks"
import type { ChartMark } from "../../app/javascript/charts/types"

const mark: ChartMark = {
  key: "me/app", number: "commits", colorClass: "os-project-2", column: 9, left: 100, top: 100, badge: "milestone", label: "Milestone: Launch, Oct 28, and 1 more",
  entries: [{ id: 8, title: "Launch", badge: "milestone", kind: "Milestone", date: "Oct 28" }, { id: 7, title: "Beta", badge: "published", kind: "Published", date: "Oct 27" }],
}

function render(each: ChartMark, lead?: Lead, opacity = 1): string {
  return renderToStaticMarkup(<Mark mark={each} opacity={opacity} lead={lead} onPoint={() => undefined} />)
}

describe("a mark on the chart", () => {
  test("links to its newest entry's row in What's new, named for a screen reader", () => {
    const html = render(mark, "news")

    expect(html).toMatch(/^<a href="#entry-8" aria-label="Milestone: Launch, Oct 28, and 1 more"/)
    expect(html).toContain("os-project-2")
  })

  test("links on the dashboard to its entries opened on its newest", () => {
    expect(render(mark, "entries")).toMatch(/^<a href="\/dashboard\?entry=8#entry-8"/)
  })

  test("stays inside the chart at its edges", () => {
    expect(render(mark, "news")).toContain("left:clamp(11px, 100%, calc(100% - 11px));top:min(100%, calc(100% - 11px))")
  })

  test("wears a flag for a milestone, a rocket for anything else shipped and a speech bubble for what was published", () => {
    expect(render(mark, "news")).toContain('d="M3 1.5a')
    expect(render({ ...mark, badge: "shipped" }, "news")).toContain('d="M14.5 1.5')
    expect(render({ ...mark, badge: "published" }, "news")).toContain('d="M3.5 2.5')
  })

  test("only marks without a lead, hidden from screen readers, fading with its line", () => {
    const html = render(mark, undefined, 0.14)

    expect(html).not.toContain("<a")
    expect(html).toMatch(/^<span aria-hidden="true"/)
    expect(html).toContain("opacity:0.14")
  })
})

describe("the dashboard opened on an entry", () => {
  test("keeps the chart's view and leaves out the entries' filters, page and tab", () => {
    expect(entriesHref(8, "https://openstage.dev/dashboard?range=90d&q=fix&type=note&repo=me%2Fapp&tab=hidden&before=2026-10-01T00%3A00%3A00Z%2C4&entry=3#entries"))
      .toBe("/dashboard?range=90d&entry=8#entry-8")
  })
})
