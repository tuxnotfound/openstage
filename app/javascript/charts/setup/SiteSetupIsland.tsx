import { useEffect, useState, type ReactNode } from "react"
import { csrfToken } from "../filter/ProjectsTable"
import type { SiteSetupView, SiteStatusView } from "../types"

// Set up site visits: three steps on one page, the next one open. A step
// that is done closes to one line. The page opens on the step its project
// is at; while it waits for the first visit it asks the server again every
// few seconds, so the visit shows without a reload. Every word but the new
// page's is the server's.

export type SiteSetupProps = SiteSetupView
export type StepState = "later" | "now" | "done"

// How often the page asks whether the first visit came, while it waits.
export const LISTEN_MS = 5000

// Each step's state for where the project stands: the line to paste and
// the wait for its first visit are open together.
export function stepStates(step: SiteStatusView["step"]): [StepState, StepState, StepState] {
  if (step === "pick") return ["now", "later", "later"]
  if (step === "line") return ["done", "now", "now"]
  return ["done", "done", "done"]
}

export function setupUrl(path: string, projectId: number): string {
  return `${path}?project=${projectId}`
}

export default function SiteSetupIsland(view: SiteSetupProps) {
  const [status, setStatus] = useState(view.status)
  const [changing, setChanging] = useState(false)
  const step = changing || !status ? "pick" : status.step
  const [pick, line, wait] = stepStates(step)
  useFirstVisit(view, step, setStatus)

  return (
    <section className="os-panel p-[clamp(16px,2.4vw,28px)]" aria-label="Steps">
      <Step n={1} state={pick} title="Pick the project and its website" place="first">
        {pick === "now" ? <PickForm view={view} /> : <Summary onChange={() => setChanging(true)} view={view} />}
      </Step>
      <Step n={2} state={line} title="Paste one line into your site">
        {line === "now" && <Line view={view} />}
        {line === "done" && <ShownLine view={view} />}
      </Step>
      <Step n={3} state={wait} title="Open your site once" place="last">
        {wait !== "later" && status && <Wait view={view} status={status} />}
      </Step>
    </section>
  )
}

// Asks where the project stands while the page waits for its first visit,
// skipping a turn while the page is out of sight. A failed ask is asked
// again on the next turn.
function useFirstVisit(view: SiteSetupProps, step: SiteStatusView["step"], setStatus: (update: (was: SiteStatusView | null) => SiteStatusView | null) => void) {
  const path = view.project?.statusPath
  useEffect(() => {
    if (step !== "line" || !path) return
    const timer = window.setInterval(() => {
      if (document.hidden) return
      void fetch(path, { credentials: "same-origin", headers: { Accept: "application/json" } })
        .then((response) => (response.ok ? (response.json() as Promise<SiteStatusView>) : null))
        .then((next) => { if (next) setStatus((was) => (was ? { ...was, step: next.step, firstVisit: next.firstVisit } : next)) })
        .catch(() => null)
    }, LISTEN_MS)
    return () => window.clearInterval(timer)
  }, [step, path, setStatus])
}

const CHECK = (
  <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" className="size-3.5">
    <path d="M3.2 8.6l3.1 3.1 6.5-7.2" />
  </svg>
)

const MARK: Record<StepState, string> = {
  later: "border-[1.5px] border-ink-3 text-ink-3",
  now: "border-[1.5px] border-accent text-ink",
  done: "bg-accent text-on-accent",
}

export function Step({ n, state, title, place, children }: { n: number; state: StepState; title: string; place?: "first" | "last"; children?: ReactNode }) {
  const edge = place === "first" ? "pt-0 pb-5" : `border-t border-line pt-5 ${place === "last" ? "pb-0" : "pb-5"}`
  return (
    <div className={`grid grid-cols-[28px_minmax(0,1fr)] gap-x-4 ${edge}`}>
      <span className={`box-border inline-flex size-7 items-center justify-center rounded-full text-sm font-bold ${MARK[state]}`} aria-hidden="true">
        {state === "done" ? CHECK : n}
      </span>
      <div className={`min-w-0 [&>*+*]:mt-3.5 ${state === "done" ? "[&>h2+*]:mt-0.5" : "[&>h2+*]:mt-3"}`}>
        <h2 className={state === "later" ? "os-h3 leading-7 text-ink-3" : "os-h3 leading-7"}>{title}</h2>
        {children}
      </div>
    </div>
  )
}

const QUIET_BUTTON = "cursor-pointer rounded border-0 bg-transparent p-0 text-[13px] font-bold whitespace-nowrap text-ink-2 underline underline-offset-3 hover:text-ink"

// The first step, open: the project, its website and Continue, which keeps
// the website and picks Openstage's script. A project picked in the field
// opens the page on it, its own website filled. A builder with no project
// yet is asked to connect GitHub, as an empty chart asks.
function PickForm({ view }: { view: SiteSetupProps }) {
  const project = view.project
  if (!project) {
    return <p className="os-sm m-0 text-ink-2">Connect your repos to see your commits here. <a href={view.paths.connect} className="os-link text-[13px]">Connect GitHub</a></p>
  }

  const open = (id: string) => {
    const url = setupUrl(view.paths.setup, Number(id))
    if (window.Turbo) window.Turbo.visit(url)
    else window.location.assign(url)
  }

  return (
    <form method="post" action={view.paths.setup} data-turbo="false" className="[&>*+*]:mt-3.5">
      <input type="hidden" name="_method" value="patch" />
      <input type="hidden" name="authenticity_token" value={csrfToken()} />
      <input type="hidden" name="project_id" value={project.id} />
      {view.refusal && <p role="alert" className="os-sm m-0 font-bold text-down">{view.refusal}</p>}
      <div className="grid grid-cols-[minmax(0,1fr)] gap-3 min-[901px]:grid-cols-[minmax(0,1fr)_minmax(0,1.5fr)]">
        <label className="os-fieldset min-w-0">
          <span className="os-label">Project</span>
          <select className="os-field cursor-pointer" defaultValue={project.id} onChange={(event) => open(event.target.value)}>
            {view.projects.map((each) => <option key={each.id} value={each.id}>{each.label}</option>)}
          </select>
        </label>
        <label className="os-fieldset min-w-0">
          <span className="os-label">Website</span>
          <input type="url" name="website" className="os-field" defaultValue={project.website} placeholder="https://" />
        </label>
      </div>
      {view.free && (
        <p className="os-sm m-0 text-ink-2">Free counts site visits for one project. <a href={view.paths.pricing} className="os-link text-[13px]">Go Pro</a> to count them for every project.</p>
      )}
      <div><button type="submit" className="os-btn">Continue</button></div>
    </form>
  )
}

function Summary({ view, onChange }: { view: SiteSetupProps; onChange: () => void }) {
  return (
    <p className="m-0 text-sm text-ink-2">
      <b>{view.project?.name}</b>, on {view.project?.host}
      <button type="button" className={`ml-2.5 ${QUIET_BUTTON}`} onClick={onChange}>Change</button>
    </p>
  )
}

// The second step, open: where the line goes, the line, Copy the line,
// and what it counts.
function Line({ view }: { view: SiteSetupProps }) {
  const project = view.project
  if (!project?.line) return null
  return (
    <>
      <p className="os-sm m-0 text-ink-2">Into the head of every page on {project.host}, or once in the layout your pages share:</p>
      <LineToCopy line={project.line} />
      <p className="os-note">{project.note} <a href={view.paths.privacy} className="os-link text-[13px]">What it counts</a></p>
    </>
  )
}

// The second step, done: one line, and the line itself on asking.
function ShownLine({ view }: { view: SiteSetupProps }) {
  const [shown, setShown] = useState(false)
  const project = view.project
  return (
    <>
      <p className="m-0 text-sm text-ink-2">
        The line is on {project?.host}
        {!shown && <button type="button" className={`ml-2.5 ${QUIET_BUTTON}`} onClick={() => setShown(true)}>Show the line</button>}
      </p>
      {shown && project?.line && <LineToCopy line={project.line} />}
    </>
  )
}

// The line breaks between its words before it breaks inside one, so it
// keeps to its box at any width. Copy's words are the app's (clipboard).
function LineToCopy({ line }: { line: string }) {
  const [said, setSaid] = useState<string | null>(null)
  const copy = () => {
    const flash = (words: string) => {
      setSaid(words)
      window.setTimeout(() => setSaid(null), 1500)
    }
    navigator.clipboard.writeText(line).then(() => flash("Copied"), () => flash("Press Cmd+C"))
  }
  return (
    <div className="grid justify-items-start gap-2.5">
      <code className="os-code box-border block w-full leading-normal whitespace-pre-wrap [overflow-wrap:anywhere]">{line}</code>
      <button type="button" className="os-btn" onClick={copy}>{said ?? "Copy the line"}</button>
    </div>
  )
}

// The third step: the wait and the way to the site, then the app's line
// for the first visit and where to go next; the switch for what visitors
// see is there from the wait on.
function Wait({ view, status }: { view: SiteSetupProps; status: SiteStatusView }) {
  const project = view.project
  if (!project) return null
  return (
    <>
      {status.step === "done" ? (
        <p className="m-0 text-[15px] font-bold text-up" role="status">{status.firstVisit}</p>
      ) : (
        <div className="flex flex-wrap items-center gap-x-3 gap-y-2.5">
          <span className="size-2.5 flex-none rounded-full bg-ink-3 shadow-[0_0_0_4px_color-mix(in_oklab,var(--color-ink-3)_25%,transparent)]" aria-hidden="true" />
          <span className="os-sm" role="status">Waiting for the first visit</span>
          {project.visit && (
            <a href={project.visit} target="_blank" rel="noopener" className="os-btn2 sm min-[901px]:ml-auto">Open {project.host} <span aria-hidden="true">↗</span></a>
          )}
        </div>
      )}
      <Seen view={view} initial={status.seen} />
      {status.step === "done" && (
        <div className="flex flex-wrap gap-2.5">
          <a href={project.page} className="os-btn">View its page <span aria-hidden="true">↗</span></a>
          <a href={project.dashboard} className="os-btn2">Back to the dashboard</a>
        </div>
      )}
    </>
  )
}

// Whether visitors see its site visits: the switch its own view has, saved
// the way it saves (Projects::NumbersController), back where it was if the
// save fails, with the dashboard's words for that.
function Seen({ view, initial }: { view: SiteSetupProps; initial: boolean }) {
  const [seen, setSeen] = useState(initial)
  const [failed, setFailed] = useState(false)
  const project = view.project
  if (!project) return null

  async function flip() {
    if (!project) return
    const next = !seen
    setSeen(next)
    setFailed(false)
    const response = await fetch(project.numbers, {
      method: "PATCH", credentials: "same-origin",
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": csrfToken() },
      body: JSON.stringify({ number: "visits", shown: next }),
    }).catch(() => null)
    if (response?.ok) return window.Turbo?.cache.exemptPageFromCache()
    setSeen(!next)
    setFailed(true)
  }

  return (
    <>
      <div className="flex items-center gap-3 text-[15px] font-semibold">
        <button type="button" role="switch" aria-checked={seen} aria-label={`Show site visits on ${project.name}'s page`} className="os-switch" onClick={() => { void flip() }} />
        <span>Visitors see site visits on {project.name}'s page</span>
      </div>
      {failed && <p role="status" className="os-note">That switch did not save. Try it again.</p>}
    </>
  )
}
