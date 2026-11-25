import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test } from "vitest"
import ProjectsTab, { keepPlace, listUrl, pageUrl } from "../../app/javascript/charts/dashboard/ProjectsTab"
import type { DashboardLines, DashboardList } from "../../app/javascript/charts/types"

// The list as the server sends it (DashboardProjectsSerializer): two
// projects, one with a colour, one off the stage.
const list: DashboardList = {
  many: false, count: 2, view: "all", query: "", page: 1, pages: 1, pinned: 1, views: [], range: null, empty: null, connect: null,
  rows: [
    { id: 7, name: "shipnote", colorClass: "os-project-1", pinned: true, stage: true, switch: "/github_repos/7" },
    { id: 9, name: "tinycal", colorClass: null, pinned: false, stage: false, switch: "/github_repos/9" },
  ],
}

// shipnote's numbers (DashboardLinesSerializer), before anything is set up.
const lines: DashboardLines = {
  id: 7, name: "shipnote", colorClass: "os-project-1", page: "/mara/shipnote", edit: "/projects/7/edit",
  lines: [
    { key: "commits", name: "Commits", state: "From GitHub", sep: false,
      control: { kind: "switch", on: true, dead: false, path: "/projects/7/numbers", number: "commits", aria: "Show Commits for shipnote", filled: false } },
    { key: "visits", name: "Site visits", state: "Not counted yet", sep: false,
      control: { kind: "link", label: "Set up site visits", path: "/dashboard/site-visits?project=7", aria: "Set up site visits for shipnote", filled: true } },
    { key: "mrr", name: "MRR", state: "From Stripe. On Free only you see it.", sep: false, control: { kind: "pro", filled: false } },
  ],
}

const render = (props: Partial<Parameters<typeof ProjectsTab>[0]> = {}) =>
  renderToStaticMarkup(<ProjectsTab initial={list} endpoint="/api/dashboard/projects" open={null} row={null} history={[]} {...props} />)

describe("the addresses", () => {
  test("a view of the list leaves its defaults out", () => {
    expect(listUrl("/api/dashboard/projects", { view: "pinned", query: "", page: 1 })).toBe("/api/dashboard/projects?view=pinned")
    expect(listUrl("/api/dashboard/projects", { view: "all", query: " zeph ", page: 3 })).toBe("/api/dashboard/projects?view=all&q=zeph&page=3")
  })

  test("the page's own address names the project whose numbers are open, keeps the tab, and drops the row it landed on", () => {
    expect(pageUrl("https://openstage.dev/dashboard?row=9", 7)).toBe("https://openstage.dev/dashboard?project=7")
    expect(pageUrl("https://openstage.dev/dashboard?project=7&tab=projects", null)).toBe("https://openstage.dev/dashboard?tab=projects")
  })
})

describe("a row's switch", () => {
  test("keeps every row in its place, in its new state, with the new counts, even one that left the view", () => {
    const fresh: DashboardList = { ...list, pinned: 0, rows: [{ ...list.rows[1]!, stage: true }] }
    const kept = keepPlace(list, fresh)

    expect(kept.rows.map((row) => [row.name, row.stage])).toEqual([["shipnote", true], ["tinycal", true]])
    expect(kept.pinned).toBe(0)
  })
})

describe("the tab", () => {
  test("opens with the list alone: a row says it opens, wears its colour while pinned, and has its switch, On your stage", () => {
    const html = render()

    expect(html).toContain('<div class="dt-two">')
    expect(html).toContain('<button type="button" class="dt-pick dt-name os-project-1" aria-expanded="false" aria-label="Show the numbers of shipnote">')
    expect(html).toContain('<span class="os-dot bg-(--project)" aria-hidden="true"></span><span class="dt-pick-name" title="shipnote">shipnote</span><span class="dt-chev" aria-hidden="true"></span>')
    expect(html).toContain('<div class="dt-row dt-lgrid off">')
    expect(html).toContain('<span class="dt-nodot" aria-hidden="true"></span><span class="dt-pick-name" title="tinycal">tinycal</span>')
    expect(html).toContain('role="switch" aria-checked="false" aria-label="Show tinycal on your stage" class="os-switch"')
    expect(html).toContain('<div class="dt-side" inert="">')
    expect(html).not.toContain("dt-tools")
  })

  test("opens on a project's numbers from the address, its row tinted, a line each with its one control, the first step filled", () => {
    const html = render({ open: lines })

    expect(html).toContain('<div class="dt-two open">')
    expect(html).toContain('<div class="dt-row dt-lgrid sel">')
    expect(html).toContain('aria-expanded="true" aria-label="Close the numbers of shipnote"')
    expect(html).toContain('<section class="dt-pane" aria-label="The numbers of shipnote">')
    expect(html).toContain('<button type="button" class="dt-back"><span class="dt-chev back" aria-hidden="true"></span>Projects</button>')
    expect(html).toContain('<a href="/mara/shipnote" class="os-btn2 dt-small">Its page <span aria-hidden="true">↗</span></a>')
    expect(html).toContain('<a href="/projects/7/edit" class="os-btn2 dt-small" aria-label="Edit shipnote">Edit</a>')
    expect(html).toContain('aria-label="Close the numbers of shipnote">Close</button>')
    expect(html).toContain('<div class="dt-line-head" aria-hidden="true"><span>Number</span><span>Visitors see</span></div>')
    expect(html).toContain('role="switch" aria-checked="true" aria-disabled="false" aria-label="Show Commits for shipnote" class="os-switch"')
    expect(html).toContain('<a href="/dashboard/site-visits?project=7" class="os-btn sm" aria-label="Set up site visits for shipnote">Set up site visits</a>')
    expect(html).toContain('<span class="dt-line-state">From Stripe. On Free only you see it.</span></div><div class="dt-line-do"><span class="os-tag pro">✦ Pro</span>')
  })

  test("past ten projects, has the views with their counts, the search, and the pages", () => {
    const many: DashboardList = {
      ...list, many: true, view: "all", page: 2, pages: 16, range: "26–50 of 394",
      views: [{ key: "pinned", label: "Pinned", count: "10" }, { key: "all", label: "All", count: "394" }, { key: "hidden", label: "Hidden", count: "3" }],
    }
    const html = render({ initial: many })

    expect(html).toContain('<button type="button" class="os-pill" aria-pressed="true">All 394</button>')
    expect(html).toContain('placeholder="Find a project" aria-label="Find a project"')
    expect(html).toContain('<span class="os-sm os-muted">26–50 of 394</span>')
    expect(html).toContain('class="os-btn2 dt-small" aria-disabled="false">Previous</button>')
  })

  test("asks a builder with no project yet to connect GitHub, and keeps the sync history at the list's foot", () => {
    const html = render({ initial: { ...list, rows: [], count: 0, empty: "Connect your repos to see your commits here.", connect: "/github_app/install" },
                          history: [{ state: "up", source: "GitHub", added: 4, ago: "2 hours ago" }] })

    expect(html).toContain('<p class="dt-empty">Connect your repos to see your commits here. <a href="/github_app/install" class="os-link text-[13px]">Connect GitHub</a></p>')
    expect(html).toContain('<summary>Sync history</summary><ul><li><span><i class="bg-up"></i>GitHub<span class="os-muted"> +4</span></span><time class="os-muted">2 hours ago</time></li></ul>')
  })
})
