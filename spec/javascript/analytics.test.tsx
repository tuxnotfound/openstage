import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test, vi } from "vitest"
import AnalyticsTabs, { tabHref } from "../../app/javascript/charts/analytics/AnalyticsTabs"
import GoPro from "../../app/javascript/charts/analytics/GoPro"
import { PageListsView, RankedList, SiteListsView } from "../../app/javascript/charts/analytics/RankedList"
import Tiles from "../../app/javascript/charts/analytics/Tiles"
import ProjectsTable, { type RowTargets } from "../../app/javascript/charts/filter/ProjectsTable"
import type { LockedView, Ranked, TabLink, TableRow, Tile } from "../../app/javascript/charts/types"

// The words on screen, a space between each element's.
const words = (html: string) => html.replace(/<[^>]+>/g, " ").replace(/&#x27;/g, "'").replace(/\s+/g, " ").trim()

const tile = (key: string, label: string, value: string, more: Partial<Tile> = {}): Tile => ({
  key, label, word: label.toLowerCase(), group: "On your websites", value,
  split: [{ key: "me/app", colorClass: "os-project-1", value: 3 }], change: { arrow: "▲", text: "120%", up: true }, figure: false, suffix: null, ...more,
})
const events = { toggle: () => {}, warm: () => {}, focus: () => {} }

const tabs: TabLink[] = [
  { key: "overview", label: "Overview", pro: false, path: "/analytics" },
  { key: "commits", label: "Commits", pro: false, path: "/analytics?tab=commits" },
  { key: "visits", label: "Site visits", pro: false, path: "/analytics?tab=visits" },
  { key: "mrr", label: "MRR", pro: true, path: "/analytics?tab=mrr" },
  { key: "openstage", label: "Openstage views", pro: true, path: "/analytics?tab=openstage" },
]

const row = (label: string, count: string, width: number, more: Partial<Ranked["rows"][number]> = {}) =>
  ({ label, count, width, colorClass: null, of: null, other: false, ...more })

describe("analytics' tiles", () => {
  test("make a toggle of a number with lines, pressed while drawn, and a figure of one beside it, no button", () => {
    const html = renderToStaticMarkup(
      <Tiles tiles={[tile("visits", "Site visits", "21,498"), tile("site_visitors", "Site visitors", "12,931", { figure: true })]} lines={{ visits: 0 }} indexed={false} {...events} />,
    )

    expect(html.match(/<button/g)).toHaveLength(1)
    expect(html).toContain('aria-pressed="true"')
    expect(words(html)).toBe("Site visits 21,498 ▲ up 120% Site visitors 12,931 ▲ up 120%")
    expect(html).toMatch(/<div class="[^"]*border-transparent[^"]*"><span[^>]*>Site visitors/)
  })

  test("dash a number not drawn while three are, and say why", () => {
    const html = renderToStaticMarkup(
      <Tiles tiles={[tile("commits", "Commits", "203"), tile("views", "Views", "1,018")]} lines={{ commits: 0, visits: 1, mrr: 2 }} indexed {...events} />,
    )

    expect(html).toContain('aria-pressed="false" title="Switch a number off first"')
    expect(html).toContain("border-dashed")
  })
})

describe("analytics' tabs", () => {
  test("link each tab to its address with the window and the projects in view, the current one marked, and Pro's mark on the tabs Free does not open", () => {
    const html = renderToStaticMarkup(<AnalyticsTabs tabs={tabs} current="visits" range="90d" projects={["me/app", "page"]} defaultRange="30d" />)

    expect([...html.matchAll(/href="([^"]+)"/g)].map((match) => match[1]?.replaceAll("&amp;", "&"))).toEqual([
      "/analytics?range=90d&projects=me/app,page", "/analytics?tab=commits&range=90d&projects=me/app,page", "/analytics?tab=visits&range=90d&projects=me/app,page",
      "/analytics?tab=mrr&range=90d&projects=me/app,page", "/analytics?tab=openstage&range=90d&projects=me/app,page",
    ])
    expect(html).toMatch(/aria-current="page"[^>]*>Site visits</)
    expect(words(html)).toBe("Overview Commits Site visits MRR ✦ Pro Openstage views ✦ Pro")
  })

  test("leave the default window out, and days picked in", () => {
    expect(tabHref("/analytics?tab=commits", "30d", [], "30d")).toBe("/analytics?tab=commits")
    expect(tabHref("/analytics", "2026-10-01..2026-10-10", [], "30d")).toBe("/analytics?range=2026-10-01..2026-10-10")
    expect(tabHref("/analytics", null, [], "30d")).toBe("/analytics")
  })
})

describe("a ranked list", () => {
  test("draws each row's bar at its share, a dot with its project's name for a screen reader, and Other with no bar", () => {
    const ranked: Ranked = { rows: [row("/", "9,580", 100, { colorClass: "os-project-1", of: "shipnote" }), row("/play", "681", 7.1), row("Other", "3,312", 0, { other: true })], empty: null }
    const html = renderToStaticMarkup(<RankedList id="site-pages" title="Pages" unit="Views" ranked={ranked} />)

    expect(html.match(/<li /g)).toHaveLength(3)
    expect(html.match(/bg-bar/g)).toHaveLength(2)
    expect(html).toContain('style="width:7.1%"')
    expect(html).toContain('class="os-dot os-project-1 bg-(--project)" title="shipnote"')
    expect(words(html)).toBe("Pages Views / , shipnote 9,580 /play 681 Other 3,312")
  })

  test("says its line with no row", () => {
    const html = renderToStaticMarkup(<RankedList id="page-countries" title="Countries" unit="Views" ranked={{ rows: [], empty: "No countries in the last 30 days." }} />)

    expect(words(html)).toBe("Countries Views No countries in the last 30 days.")
    expect(html).not.toContain("<ul")
  })

  test("of the websites, makes way for one line and the link to set one up while none counts site visits", () => {
    const none: Ranked = { rows: [], empty: null }
    const html = renderToStaticMarkup(<SiteListsView site={{ pages: none, sources: none, refs: none, countries: none,
      empty: "None of the projects in view counts site visits.", setup: { text: "Set up app's site visits", path: "/projects/1/edit?site=open#site-visits" } }} />)

    expect(words(html)).toBe("None of the projects in view counts site visits. Set up app's site visits")
  })

  test("of the builder's pages, ends with where the badge and the embed were shown", () => {
    const none: Ranked = { rows: [], empty: "No views yet." }
    const html = renderToStaticMarkup(<PageListsView pages={{ sources: none, countries: none, links: none,
      badges: [{ label: "README badge", count: "1,842", sites: "3 sites" }, { label: "Embed widget", count: "261", sites: "1 site" }] }} />)

    expect(words(html)).toContain("Badge and embed Times shown README badge 3 sites 1,842 Embed widget 1 site 261")
  })
})

describe("the Go Pro view", () => {
  test("posts to checkout outside Turbo, with the server's words", () => {
    const view: LockedView = { locked: true, tab: "mrr", tabs, pitch: "Each project's MRR and paying customers.", checkout: { label: "Go Pro for $7 a month", path: "/checkout" } }
    vi.stubGlobal("document", { querySelector: () => ({ content: "token" }) })
    const html = renderToStaticMarkup(<GoPro view={view} />)
    vi.unstubAllGlobals()

    expect(html).toContain('<form class="mt-[18px]" data-turbo="false" action="/checkout" method="post">')
    expect(html).toContain('name="authenticity_token" value="token"')
    expect(words(html)).toBe("Each project's MRR and paying customers. Go Pro for $7 a month")
  })
})

describe("analytics' table", () => {
  const target = { go: () => {}, warm: () => {} }
  const rows: RowTargets = { box: () => target, only: () => target, all: null, refuse: () => {}, focus: () => {} }
  const tableRow = (key: string, drawable: boolean): TableRow =>
    ({ key, name: key, colorClass: "os-project-3", on: drawable, drawable, cells: [], edit: null, page: null, pin: null, switch: null })

  test("keeps the colour of a row that counts none of the tab's numbers as a swatch, with no box, and names how many projects it leaves out, with no link", () => {
    const html = renderToStaticMarkup(
      <ProjectsTable table={{ columns: [], rows: [tableRow("quill-md", false)], stack: "md", more: { text: "12 more projects", anchor: null } }}
                     drawn={[]} lines={{}} indexed={false} words="last 30 days" focused={null} rows={rows} beside />,
    )

    expect(html).not.toContain('type="checkbox"')
    expect(html).toContain('<span class="os-project-3 size-2 rounded-[2px] bg-(--project)">')
    expect(html).toContain(", draws no line")
    expect(html).not.toContain("<a ")
    expect(words(html)).toContain("12 more projects")
    expect(html).not.toContain("mt-5")
  })
})
