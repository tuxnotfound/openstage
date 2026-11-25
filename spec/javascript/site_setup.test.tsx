import { renderToStaticMarkup } from "react-dom/server"
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest"
import SiteSetupIsland, { setupUrl, stepStates } from "../../app/javascript/charts/setup/SiteSetupIsland"
import type { SiteSetupView, SiteStatusView } from "../../app/javascript/charts/types"

// The page as the server sends it (SiteVisitsSetupSerializer), on Free,
// its project picked and nothing set up.
const view: SiteSetupView = {
  projects: [{ id: 2, label: "aardvark" }, { id: 7, label: "shipnote" }],
  free: true,
  refusal: null,
  project: {
    id: 7, name: "shipnote", host: "shipnote.app", website: "https://shipnote.app", visit: "https://shipnote.app",
    line: '<script defer src="https://openstage.dev/v.js" data-project="os_k3vq8dtz1mxw"></script>', note: "It counts only on shipnote.app.",
    page: "/mara/shipnote", dashboard: "/dashboard?project=7", numbers: "/projects/7/numbers", statusPath: "/api/site_visits/7",
  },
  status: { step: "pick", firstVisit: null, seen: true },
  paths: { setup: "/dashboard/site-visits", pricing: "/pricing", privacy: "/privacy#builders-sites", connect: "/github_app/install" },
}

const at = (status: SiteStatusView) => renderToStaticMarkup(<SiteSetupIsland {...view} status={status} />)

describe("the steps' states", () => {
  test("open the next step, and the line and the wait together", () => {
    expect(stepStates("pick")).toEqual(["now", "later", "later"])
    expect(stepStates("line")).toEqual(["done", "now", "now"])
    expect(stepStates("done")).toEqual(["done", "done", "done"])
  })

  test("a project picked in the field opens the page on it", () => {
    expect(setupUrl("/dashboard/site-visits", 2)).toBe("/dashboard/site-visits?project=2")
  })
})

describe("the page", () => {
  beforeEach(() => { vi.stubGlobal("document", { querySelector: () => ({ content: "token" }) }) })
  afterEach(() => { vi.unstubAllGlobals() })

  test("opens on the first step: the project, its website, Free's line and Continue, which saves through the page", () => {
    const html = at({ step: "pick", firstVisit: null, seen: true })

    expect(html).toContain('<form data-turbo="false" class="[&amp;&gt;*+*]:mt-3.5" action="/dashboard/site-visits" method="post">')
    expect(html).toContain('<input type="hidden" name="_method" value="patch"/><input type="hidden" name="authenticity_token" value="token"/>')
    expect(html).toContain('<input type="hidden" name="project_id" value="7"/>')
    expect(html).toContain('<option value="7" selected="">shipnote</option>')
    expect(html).toContain('<input type="url" class="os-field" placeholder="https://" name="website" value="https://shipnote.app"/>')
    expect(html).toContain('Free counts site visits for one project. <a href="/pricing" class="os-link text-[13px]">Go Pro</a> to count them for every project.')
    expect(html).toContain(">Continue</button>")
    expect(html).not.toContain("<code")
  })

  test("says a refusal in the first step", () => {
    const html = renderToStaticMarkup(<SiteSetupIsland {...view} refusal="Add shipnote's website first: the script counts only there." />)

    expect(html).toContain('<p role="alert" class="os-sm m-0 font-bold text-down">Add shipnote&#x27;s website first: the script counts only there.</p>')
  })

  test("once the script counts, closes the first step to one line and opens the line and the wait, with the switch", () => {
    const html = at({ step: "line", firstVisit: null, seen: true })

    expect(html).toContain("<b>shipnote</b>, on shipnote.app")
    expect(html).toContain(">Change</button>")
    expect(html).toContain("Into the head of every page on shipnote.app, or once in the layout your pages share:")
    expect(html).toContain("data-project=&quot;os_k3vq8dtz1mxw&quot;&gt;&lt;/script&gt;</code>")
    expect(html).toContain(">Copy the line</button>")
    expect(html).toContain('It counts only on shipnote.app. <a href="/privacy#builders-sites" class="os-link text-[13px]">What it counts</a>')
    expect(html).toContain('<span class="os-sm" role="status">Waiting for the first visit</span>')
    expect(html).toContain('<a href="https://shipnote.app" target="_blank" rel="noopener" class="os-btn2 sm min-[901px]:ml-auto">Open shipnote.app <span aria-hidden="true">↗</span></a>')
    expect(html).toContain('role="switch" aria-checked="true" aria-label="Show site visits on shipnote&#x27;s page"')
    expect(html).toContain("Visitors see site visits on shipnote&#x27;s page")
    expect(html).not.toContain("<form")
  })

  test("once the first visit came, says so in the app's words, closes the line, and leads to the project's page and the dashboard", () => {
    const html = at({ step: "done", firstVisit: "First visit received today at 14:02", seen: false })

    expect(html).toContain('<p class="m-0 text-[15px] font-bold text-up" role="status">First visit received today at 14:02</p>')
    expect(html).toContain("The line is on shipnote.app")
    expect(html).toContain(">Show the line</button>")
    expect(html).not.toContain("<code")
    expect(html).not.toContain("Waiting for the first visit")
    expect(html).toContain('role="switch" aria-checked="false"')
    expect(html).toContain('<a href="/mara/shipnote" class="os-btn">View its page <span aria-hidden="true">↗</span></a>')
    expect(html).toContain('<a href="/dashboard?project=7" class="os-btn2">Back to the dashboard</a>')
  })

  test("asks a builder with no project yet to connect GitHub", () => {
    const html = renderToStaticMarkup(<SiteSetupIsland {...view} projects={[]} project={null} status={null} />)

    expect(html).toContain('Connect your repos to see your commits here. <a href="/github_app/install" class="os-link text-[13px]">Connect GitHub</a>')
    expect(html).not.toContain("<form")
  })
})
