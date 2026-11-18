import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test, vi } from "vitest"
import AnalyticsTabs, { tabHref } from "../../app/javascript/charts/analytics/AnalyticsTabs"
import CommitPartsView from "../../app/javascript/charts/analytics/CommitPartsView"
import RevenuePartsView from "../../app/javascript/charts/analytics/RevenuePartsView"
import GoPro from "../../app/javascript/charts/analytics/GoPro"
import { PageListsView, RankedList, SiteListsView } from "../../app/javascript/charts/analytics/RankedList"
import Tiles from "../../app/javascript/charts/analytics/Tiles"
import ProjectsTable, { type RowTargets } from "../../app/javascript/charts/filter/ProjectsTable"
import type { CommitParts, LockedView, NewsItem, Ranked, RevenueParts, TabLink, TableRow, Tile } from "../../app/javascript/charts/types"

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

  test("ends each row with its words under a text column, a dash for none", () => {
    const html = renderToStaticMarkup(
      <ProjectsTable table={{ columns: [], rows: [{ ...tableRow("shipnote", true), text: "yesterday" }, { ...tableRow("quill-md", true), text: null }], stack: "md", more: null,
                              text: { label: "Last commit" } }}
                     drawn={[]} lines={{}} indexed={false} words="last 30 days" focused={null} rows={rows} beside />,
    )

    expect(html).toMatch(/<th scope="col"[^>]*>Last commit<\/th>/)
    expect(words(html)).toContain("shipnote Only Last commit yesterday")
    expect(words(html)).toContain("quill-md Only Last commit –")
  })
})

describe("the Commits tab's parts", () => {
  const news = (id: number, more: Partial<NewsItem> = {}): NewsItem =>
    ({ id, date: "Nov 12", badge: "shipped", kind: "Shipped", colorClass: "os-project-1", title: `Entry ${id}`, project: "shipnote", ...more })
  const hours = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((name, day) => ({
    name, cells: Array.from({ length: 24 }, (_, hour) => ({ step: (day === 0 && hour === 9 ? 4 : 0) as 0 | 4, title: `${name} ${String(hour).padStart(2, "0")}:00` })),
  }))
  const parts = (items: NewsItem[]): CommitParts => ({ hours, news: items, newsEmpty: "Nothing shipped or published in the last 30 days." })

  test("draw a cell per weekday and hour, Monday first, darker with more, each saying its count on hover", () => {
    const html = renderToStaticMarkup(<CommitPartsView commits={parts([])} words="last 30 days" />)

    expect(html).toContain('role="img" aria-label="Commits by weekday and hour, last 30 days"')
    expect(html.match(/title="[A-Z][a-z]{2} \d\d:00"/g)).toHaveLength(7 * 24)
    expect(html).toContain('title="Mon 09:00" class="aspect-square max-h-[22px] rounded bg-heat-4"')
    expect(html.match(/rounded bg-line/g)).toHaveLength(7 * 24 - 1)
    expect(words(html)).toMatch(/^When you commit Fewer More Mon .* Sun 00:00 06:00 12:00 18:00 What's new Nothing shipped or published in the last 30 days\.$/)
  })

  test("list what's new, newest first, each row an entry's own, eight of them and the rest behind Show all", () => {
    const html = renderToStaticMarkup(<CommitPartsView commits={parts([news(9, { badge: "milestone", kind: "Milestone", title: "Launched" }), ...Array.from({ length: 9 }, (_, i) => news(i))])} words="last 30 days" />)

    expect(words(html)).toContain("What's new Milestone: Launched shipnote · Nov 12 Shipped: Entry 0 shipnote · Nov 12")
    expect([...html.matchAll(/<li id="(entry-\d+)"/g)].map((match) => match[1])).toEqual(["entry-9", ...Array.from({ length: 9 }, (_, i) => `entry-${i}`)])
    expect(html).toMatch(/<summary[^>]*>Show all 10<\/summary><ul[^>]*><li id="entry-7"/)
    expect(html).toContain('<span class="os-project-1 inline-flex size-[22px]')
  })
})

describe("the MRR tab's parts", () => {
  const product = { label: "shipnote Pro, monthly", count: "$612", width: 100, colorClass: "os-project-1", of: "shipnote", other: false, subscriptions: "68 subscriptions" }
  const step = (label: string, amount: string, up: boolean | null) => ({ label, amount, up, mrr: "$1,322" })

  test("list each product with its project's dot and subscriptions, verified with Stripe, and MRR by week with each week's change, its arrow in the colour of its way", () => {
    const revenue: RevenueParts = {
      products: [product], empty: null,
      steps: { title: "MRR by week", rows: [step("Week of Nov 16–18", "–", null), step("Week of Nov 9–15", "$28", true), step("Week of Nov 2–8", "$65", false)] },
    }
    const html = renderToStaticMarkup(<RevenuePartsView revenue={revenue} />)

    expect(words(html)).toBe(
      "Products Verified with Stripe shipnote Pro, monthly , shipnote 68 subscriptions $612 MRR by week MRR by week: what each added or took, and where MRR stood at its end Change MRR "
      + "Week of Nov 16–18 – $1,322 Week of Nov 9–15 ▲ up $28 $1,322 Week of Nov 2–8 ▼ down $65 $1,322",
    )
    expect(html).toContain('<span class="text-[11px] text-up" aria-hidden="true">▲</span>')
    expect(html).toContain('<span class="text-[11px] text-down" aria-hidden="true">▼</span>')
    expect(html).not.toContain("Show all")
  })

  test("keep thirteen rows and the rest behind Show all, and say when no product counts for a project", () => {
    const rows = Array.from({ length: 36 }, (_, i) => step(`Month ${i}`, "$1", true))
    const html = renderToStaticMarkup(<RevenuePartsView revenue={{ products: [], empty: null, steps: { title: "MRR by month", rows } }} />)
    expect(html.match(/<tr class="border-t/g)).toHaveLength(13)
    expect(words(html)).toContain("Show all 36")
    expect(html).not.toContain("Products")

    const empty = renderToStaticMarkup(<RevenuePartsView revenue={{ products: [], empty: "No Stripe product counts for a project yet.", steps: { title: "MRR by week", rows: [] } }} />)
    expect(words(empty)).toBe("No Stripe product counts for a project yet.")
  })
})
