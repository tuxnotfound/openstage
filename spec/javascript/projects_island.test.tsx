import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test } from "vitest"
import ProjectsIsland, { ListRow, listUrl } from "../../app/javascript/charts/projects/ProjectsIsland"
import type { ProjectListRow, ProjectListView } from "../../app/javascript/charts/types"

// A row of the stage's list as the server sends it (ProjectListSerializer).
const row: ProjectListRow = {
  key: "me/sauna", name: "sauna", path: "/me/sauna", description: "Sauna math.", live: true, archived: false,
  commits: 1, countWords: "commit in 12 months", line: "M0.0 5.1 L400.0 56.0", last: "2 days ago",
}

const view: ProjectListView = {
  title: "2 more projects", sort: "latest", query: "", live: false, page: 1, pages: 2,
  sorts: [{ key: "latest", label: "Latest" }, { key: "commits", label: "Most commits" }, { key: "name", label: "A–Z" }],
  liveLabel: "Live · 1", range: "1–25 of 30", empty: null, rows: [row],
}

describe("the address of a view of the list", () => {
  test("leaves its defaults out, as Progress::Listing does, so one view has one address", () => {
    const ask = { sort: "latest", query: "", live: false, page: 1 }

    expect(listUrl("/api/projects/me", ask, "latest")).toBe("/api/projects/me")
    expect(listUrl("/api/projects/me", { sort: "name", query: " sauna ", live: true, page: 2 }, "latest")).toBe("/api/projects/me?sort=name&q=sauna&live=1&page=2")
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
