import { readFileSync } from "node:fs"
import { describe, expect, test } from "vitest"

// Openstage's script (public/v.js) as a project's website runs it, with the
// browser it reads stood in for: what it sends is what the tests read.
const script = readFileSync(new URL("../../public/v.js", import.meta.url), "utf8")

function open(href: string, referrer: string) {
  const sent: unknown[] = []
  const listeners = new Map<string, () => void>()
  const location = { href, protocol: new URL(href).protocol, hostname: new URL(href).hostname }
  const history = {
    pushState(_state: unknown, _title: string, url: string) {
      location.href = new URL(url, location.href).href
    },
  }
  const browser = {
    document: { referrer, currentScript: { src: "https://openstage.dev/v.js", getAttribute: () => "os_abc123" } },
    navigator: { webdriver: false, sendBeacon: (_url: string, body: string) => sent.push(JSON.parse(body)) > 0 },
    window: { addEventListener: (type: string, listener: () => void) => listeners.set(type, listener) },
  }
  new Function("document", "navigator", "location", "history", "window", script)(browser.document, browser.navigator, location, history, browser.window)
  const back = (url: string) => {
    location.href = url
    listeners.get("popstate")?.()
  }
  return { sent, history, back }
}

describe("Openstage's script on a project's website", () => {
  test("sends the referrer with a page load's first view, and not with the app's page changes after it", () => {
    const site = open("https://shipnote.app/pricing?ref=hn#plans", "https://news.ycombinator.com/")
    site.history.pushState({}, "", "/docs")
    site.back("https://shipnote.app/pricing?ref=hn")

    expect(site.sent).toEqual([
      { p: "os_abc123", u: "https://shipnote.app/pricing?ref=hn", r: "https://news.ycombinator.com/" },
      { p: "os_abc123", u: "https://shipnote.app/docs" },
      { p: "os_abc123", u: "https://shipnote.app/pricing?ref=hn" },
    ])
  })

  test("counts a page change only when its path changes, a filter in the query string keeping the page", () => {
    const site = open("https://shipnote.app/dashboard", "")
    site.history.pushState({}, "", "/dashboard?range=90d")
    site.history.pushState({}, "", "/docs?tab=api")
    site.history.pushState({}, "", "/docs?tab=cli")
    site.back("https://shipnote.app/dashboard?range=90d")

    expect(site.sent).toEqual([
      { p: "os_abc123", u: "https://shipnote.app/dashboard", r: "" },
      { p: "os_abc123", u: "https://shipnote.app/docs?tab=api" },
      { p: "os_abc123", u: "https://shipnote.app/dashboard?range=90d" },
    ])
  })

  test("sends an empty referrer as it is, for a visitor who came from no page", () => {
    expect(open("https://shipnote.app/", "").sent).toEqual([{ p: "os_abc123", u: "https://shipnote.app/", r: "" }])
  })

  test("sends nothing from localhost", () => {
    expect(open("http://localhost:3000/", "").sent).toEqual([])
  })
})
