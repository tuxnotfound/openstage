import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test } from "vitest"
import AnalyticsPanels from "../../app/javascript/charts/analytics/AnalyticsPanels"
import { PANELS_PARAM, panelsIn, panelsUrl } from "../../app/javascript/charts/analytics/panels"
import { ours, marked } from "../../app/javascript/charts/history"
import type { AnalyticsView, WebsitesView } from "../../app/javascript/charts/types"

const websites: WebsitesView = {
  sources: [{ label: "Hacker News", count: "5", width: 100 }, { label: "Other", count: "2", width: 40 }],
  refs: [],
  countries: [{ label: "PT", count: "3" }],
  pages: [{ label: "/docs/*", count: "9" }],
  empty: null,
  setup: null,
}

// Only what the panels read; the chart filter's part stays out of it.
function viewWith(site: WebsitesView): AnalyticsView {
  return {
    words: "last 30 days", quiet: "in the last 30 days", websites: site,
    sources: [{ label: "Reddit", count: "1", width: 100 }], countries: [], links: [], badges: [{ label: "README badge", count: "0", sites: "0 sites" }],
  } as unknown as AnalyticsView
}

// The words on screen, a space between each element's.
const words = (html: string) => html.replace(/<[^>]+>/g, " ").replace(/&#x27;/g, "'").replace(/\s+/g, " ").trim()

describe("the switch above analytics' panels", () => {
  test("reads the panels the page's address names, the websites' for none or for a name it does not know", () => {
    expect(panelsIn("http://x.test/analytics")).toBe("websites")
    expect(panelsIn("http://x.test/analytics?range=90d&panels=openstage")).toBe("openstage")
    expect(panelsIn("http://x.test/analytics?panels=github")).toBe("websites")
  })

  test("writes the page's address for other panels, its other params and hash kept, and the websites' left out", () => {
    expect(panelsUrl("http://x.test/analytics?show=commits,views&projects=me/app#top", "openstage"))
      .toBe("/analytics?show=commits,views&projects=me/app&panels=openstage#top")
    expect(panelsUrl("http://x.test/analytics?panels=openstage&range=90d", "websites")).toBe("/analytics?range=90d")
    expect(panelsUrl("http://x.test/analytics?panels=openstage", "websites")).toBe("/analytics")
  })

  test("leaves Back and Forward between two panels to the island, as their addresses differ only in its own params", () => {
    const own = ["range", "show", "projects", "from", "to", PANELS_PARAM]
    const state = marked(null, { page: "a", url: "/api/analytics?range=30d" })

    expect(ours(state, "a", "http://x.test/analytics?range=90d", "http://x.test/analytics?range=90d&panels=openstage", own)).toEqual({ page: "a", url: "/api/analytics?range=30d" })
    expect(ours(state, "a", "http://x.test/analytics", "http://x.test/analytics?panels=openstage", own.slice(0, -1))).toBeNull()
  })

  test("presses the panels shown, and shows only theirs: the websites' with their Other rows, or Openstage's as before", () => {
    const site = renderToStaticMarkup(<AnalyticsPanels view={viewWith(websites)} panels="websites" flip={() => {}} />)

    expect([...site.matchAll(/aria-pressed="(\w+)"[^>]*>([^<]+)</g)].map(([, pressed, label]) => [label, pressed])).toEqual([["On your websites", "true"], ["On Openstage", "false"]])
    expect(words(site)).toBe("On your websites On Openstage Visitors and page views on your websites, counted by Openstage's script. " +
      "Where visitors came from Visitors to your websites, by the site they came from, last 30 days. Hacker News 5 Other 2 Countries PT 3 " +
      "Ref tags Visitors by the ref or utm_source tag in their link, last 30 days. No ref tags in the last 30 days. " +
      "Top pages Page views on your websites, by path, last 30 days. /docs/* 9")

    const openstage = renderToStaticMarkup(<AnalyticsPanels view={viewWith(websites)} panels="openstage" flip={() => {}} />)
    expect(words(openstage)).toContain("Views and clicks out on your stage and your project pages, and where your badge and embed were shown. " +
      "Where visitors came from Views of your Openstage pages, by the site they came from, last 30 days. Reddit 1")
    expect(words(openstage)).toContain("Clicks from your Openstage pages, last 30 days. No clicks out in the last 30 days.")
    expect(openstage).not.toContain("Top pages")
  })

  test("says why the website panels are empty, with the link that sets up site visits where the server sends one", () => {
    const off = { ...websites, sources: [], countries: [], pages: [], empty: "None of the projects in view counts site visits.", setup: { text: "Set up app's site visits", path: "/projects/1/edit?site=open#site-visits" } }
    const html = renderToStaticMarkup(<AnalyticsPanels view={viewWith(off)} panels="websites" flip={() => {}} />)

    expect(html).toContain('<a class="os-link text-[13px]" href="/projects/1/edit?site=open#site-visits">Set up app&#x27;s site visits</a>')
    expect(words(html)).toMatch(/script\. None of the projects in view counts site visits\. Set up app's site visits$/)
    expect(html).not.toContain("<section")
  })
})
