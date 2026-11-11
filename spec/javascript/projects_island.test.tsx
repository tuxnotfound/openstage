import { renderToStaticMarkup } from "react-dom/server"
import { afterEach, describe, expect, test, vi } from "vitest"
import ProjectsIsland, { ListRow, listUrl } from "../../app/javascript/charts/projects/ProjectsIsland"
import type { ProjectListRow, ProjectListView } from "../../app/javascript/charts/types"

// A row of the stage's list as the server sends it (ProjectListSerializer).
const row: ProjectListRow = {
  key: "me/sauna", name: "sauna", path: "/me/sauna", description: "Sauna math.", live: true, archived: false,
  commits: 1, countWords: "commit in 12 months", line: "M0.0 5.1 L400.0 56.0", last: "2 days ago", edit: null, page: null, pin: null,
}

const view: ProjectListView = {
  title: "2 more projects", sort: "latest", query: "", live: false, page: 1, pages: 2,
  sorts: [{ key: "latest", label: "Latest" }, { key: "commits", label: "Most commits" }, { key: "name", label: "A–Z" }],
  liveLabel: "Live · 1", range: "1–25 of 30", empty: null, rows: [row], back: null,
}

describe("the address of a view of the list", () => {
  test("leaves its defaults out, as Progress::Listing does, so one view has one address", () => {
    const ask = { sort: "latest", query: "", live: false, page: 1 }

    expect(listUrl("/api/projects/me", ask, "latest")).toBe("/api/projects/me")
    expect(listUrl("/api/projects/me", { sort: "name", query: " sauna ", live: true, page: 2 }, "latest")).toBe("/api/projects/me?sort=name&q=sauna&live=1&page=2")
    expect(listUrl("/api/projects/me?dashboard=1", { ...ask, page: 3 }, "latest")).toBe("/api/projects/me?dashboard=1&page=3")
    expect(listUrl("/api/projects/me?dashboard=1", ask, "latest")).toBe("/api/projects/me?dashboard=1")
  })
})

describe("a row of the list", () => {
  test("links its name to its page, outside the stage's frame, with Live, its line in ink and its count told to a screen reader", () => {
    const html = renderToStaticMarkup(<ListRow row={row} />)

    expect(html).toContain('<a href="/me/sauna" class="truncate text-[15px] font-bold hover:underline" data-turbo-frame="_top">sauna</a>')
    expect(html).toContain('<span class="os-tag soft shrink-0">Live</span>')
    expect(html).toContain('<path d="M0.0 5.1 L400.0 56.0" fill="none" class="stroke-ink-3"')
    expect(html).toContain('1<span class="sr-only"> commit in 12 months</span>')
    expect(html).toContain('<span class="sr-only">Last commit </span>2 days ago')
  })

  test("shows no line, count or last commit while its builder hides its commits", () => {
    const html = renderToStaticMarkup(<ListRow row={{ ...row, commits: null, countWords: null, line: null, last: null }} />)

    expect(html).not.toContain("<svg")
    expect(html).not.toContain("commit")
  })
})

describe("a row of the dashboard's list", () => {
  afterEach(() => { vi.unstubAllGlobals() })

  test("adds Edit beside its name and its stage switches last, each sending the list's view along", () => {
    vi.stubGlobal("window", { location: { search: "?range=90d" } })
    vi.stubGlobal("document", { querySelector: () => null })
    const managed = { ...row, edit: "/projects/7/edit", page: { on: true, path: "/github_repos/7" }, pin: { on: false, path: "/projects/7/pin", title: "Pin it." } }
    const html = renderToStaticMarkup(<ListRow row={managed} fields={[[ "back", "list" ], [ "list_sort", "name" ]]} />)

    expect(html).toContain('<a href="/projects/7/edit" class="os-btn2 ml-auto h-[30px] shrink-0 rounded-[9px] px-3 text-[13px]" aria-label="Edit sauna">Edit</a>')
    expect(html).toContain('aria-label="Show sauna on your stage"')
    expect(html).toContain('aria-checked="false" aria-label="Pin sauna to your stage" title="Pin it." class="os-eye os-pin"')
    expect(html).toContain('<input type="hidden" name="pinned" value="true"/><input type="hidden" name="range" value="90d"/><input type="hidden" name="back" value="list"/><input type="hidden" name="list_sort" value="name"/>')
    expect(html).toContain("md:grid-cols-[minmax(0,1fr)_220px_120px_88px]")
  })
})

describe("the list", () => {
  test("marks the order and filter in view, and offers the next page alone on the first", () => {
    const html = renderToStaticMarkup(<ProjectsIsland initial={view} endpoint="/api/projects/me" />)

    expect(html).toContain('aria-pressed="true">Latest</button>')
    expect(html).toContain('aria-pressed="false">Live · 1</button>')
    expect(html).toMatch(/<button type="button" class="os-btn2 sm" disabled="">Previous<\/button>/)
    expect(html).toMatch(/<button type="button" class="os-btn2 sm">Next<\/button>/)
    expect(html).toContain("1–25 of 30")
  })
})
