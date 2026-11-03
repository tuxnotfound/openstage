import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test } from "vitest"
import Mark from "../../app/javascript/charts/filter/Marks"
import type { ChartMark } from "../../app/javascript/charts/types"

const mark: ChartMark = {
  key: "me/app", number: "commits", colorClass: "os-project-2", column: 9, left: 100, top: 100, shipped: true, label: "Shipped: Launch, Oct 28, and 1 more",
  entries: [{ id: 8, title: "Launch", shipped: true, kind: "Shipped", date: "Oct 28" }, { id: 7, title: "Beta", shipped: false, kind: "Published", date: "Oct 27" }],
}

function render(each: ChartMark, listed: boolean, opacity = 1): string {
  return renderToStaticMarkup(<Mark mark={each} opacity={opacity} listed={listed} onPoint={() => undefined} />)
}

describe("a mark on the chart", () => {
  test("links to its newest entry's row where the page lists them, named for a screen reader", () => {
    const html = render(mark, true)

    expect(html).toMatch(/^<a href="#entry-8" aria-label="Shipped: Launch, Oct 28, and 1 more"/)
    expect(html).toContain("os-project-2")
  })

  test("stays inside the chart at its edges", () => {
    expect(render(mark, true)).toContain("left:clamp(11px, 100%, calc(100% - 11px));top:min(100%, calc(100% - 11px))")
  })

  test("wears a rocket for what shipped and a speech bubble for what was published", () => {
    expect(render(mark, true)).toContain('d="M14.5 1.5')
    expect(render({ ...mark, shipped: false }, true)).toContain('d="M3.5 2.5')
  })

  test("only marks on the dashboard, hidden from screen readers, fading with its line", () => {
    const html = render(mark, false, 0.14)

    expect(html).not.toContain("<a")
    expect(html).toMatch(/^<span aria-hidden="true"/)
    expect(html).toContain("opacity:0.14")
  })
})
