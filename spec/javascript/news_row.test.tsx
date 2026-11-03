import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test } from "vitest"
import { NewsRow } from "../../app/javascript/charts/progress/ProgressIsland"
import type { ShippedItem } from "../../app/javascript/charts/types"

// A row of What's new as the server sends it (ProgressViewSerializer).
const item: ShippedItem = {
  id: 8, anchor: "entry-8", date: "Oct 28", badge: "milestone", kind: "Milestone", colorClass: "os-project-2", title: "Launch:", runIn: "Beta · Docs",
  body: "Beta\nDocs", url: "https://example.com/launch", project: "app",
}

describe("a row of What's new", () => {
  test("opens on its description, its title's link and run-in in the part that stays", () => {
    const html = renderToStaticMarkup(<NewsRow item={item} open />)

    expect(html).toMatch(/^<details id="entry-8" open="" class="os-row group\/row/)
    expect(html).toMatch(/<summary[^>]*>.*<a href="\/e\/8\/out" target="_blank"[^>]*>Launch:<\/a><span class="[^"]*group-open\/row:hidden">Beta · Docs<\/span>.*<\/summary>/)
    expect(html).toContain('<p class="os-sm os-ink2 mt-1.5 whitespace-pre-line">Beta\nDocs</p>')
  })

  test("wears its entry's mark in its project's colour, beside its kind", () => {
    const html = renderToStaticMarkup(<NewsRow item={item} open={false} />)

    expect(html).toContain('<span class="os-project-2 inline-flex size-[18px]')
    expect(html).toContain('d="M3 1.5a')
    expect(html).toContain("</span>Milestone</span>")
    expect(html).not.toContain(" open=")
  })

  test("is a plain row without a description, and leaves out a project it does not name", () => {
    const html = renderToStaticMarkup(<NewsRow item={{ ...item, body: null, project: null, runIn: "" }} open />)

    expect(html).toMatch(/^<div id="entry-8" class="os-row os-rowflex/)
    expect(html).not.toContain("<details")
    expect(html).not.toContain(">app<")
  })
})
