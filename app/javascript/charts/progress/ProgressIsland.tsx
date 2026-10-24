import { useState, type ReactNode } from "react"
import { createPortal } from "react-dom"
import LineChart, { projectClass } from "../LineChart"
import { Tally } from "./tally"
import { RANGES, RANGE_LABELS, type Item, type ProgressData, type Range } from "./types"
import * as d from "../dates"

// The commit chart and what it counts, on the builder's page, a project's page
// and the dashboard. A click recomputes it here and rewrites the URL in place,
// so the view stays shareable without a request.

export type ProgressProps = {
  data: ProgressData
  mode: "page" | "project" | "dashboard"
  defaultRange: Range
  // The What shipped section to keep in step, by element id.
  shippedTarget?: string
  // The entry a link pointed at, shown above the page instead.
  linkedId?: number | null
}

const SHOWN = 8

export default function ProgressIsland({ data, mode, defaultRange, shippedTarget, linkedId = null }: ProgressProps) {
  const [range, setRange] = useState<Range>(data.range)
  const [selected, setSelected] = useState<string[]>(data.selected)
  const tally = new Tally(data, range, selected)

  function update(nextRange: Range, nextSelected: string[]) {
    setRange(nextRange)
    setSelected(nextSelected)
    // Other params stay: the dashboard's entry filters, a linked entry.
    const params = new URLSearchParams(window.location.search)
    params.delete("range")
    if (nextRange !== defaultRange) params.set("range", nextRange)
    if (mode === "page") {
      params.delete("repo")
      params.delete("repo[]")
      nextSelected.forEach((repo) => params.append("repo[]", repo))
    }
    const query = params.toString()
    window.history.replaceState(window.history.state, "", `${window.location.pathname}${query ? `?${query}` : ""}${window.location.hash}`)
  }

  const pills = <Pills range={range} onPick={(next) => update(next, selected)} />
  const chart = (
    <LineChart lines={tally.lines} titles={tally.window.buckets.map((bucket) => tally.window.title(bucket))}
               axis={axisOf(tally)} ariaLabel={tally.ariaLabel} note={tally.note} emptyNote={tally.emptyNote}
               average={tally.average} height={mode === "dashboard" ? "h-[260px]" : ""} />
  )
  const shipped = shippedTarget && document.getElementById(shippedTarget)

  return (
    <>
      {mode === "page" && (
        <>
          <PageHeadline tally={tally} />
          <Filters tally={tally} pills={pills} onPick={(next) => update(range, next)} />
          <div className="mt-[22px]">{chart}</div>
        </>
      )}
      {mode === "project" && (
        <>
          <div className="os-between mt-7.5 items-end">
            <div>
              <p className="os-label">Commits · {tally.window.words}</p>
              <Headcount tally={tally} />
            </div>
            {pills}
          </div>
          <div className="mt-[22px]">{chart}</div>
        </>
      )}
      {mode === "dashboard" && (
        <>
          <div className="os-between">
            <h2 id="your-activity" className="os-h2">Your activity</h2>
            {pills}
          </div>
          <div className="mt-3 flex flex-wrap items-baseline gap-x-3.5 gap-y-1">
            <span className="os-num text-[56px] leading-none">{tally.totals.commits}</span>
            <span className="os-ink2">commits, {tally.window.words}<ChangeAfterDot tally={tally} /></span>
          </div>
          <div className="mt-3.5">{chart}</div>
        </>
      )}
      {shipped && createPortal(<Shipped tally={tally} linkedId={linkedId} />, shipped)}
    </>
  )
}

function axisOf(tally: Tally): string[] {
  const buckets = tally.window.buckets
  const first = buckets[0]
  const middle = buckets[Math.floor(buckets.length / 2)]
  if (!first || !middle) return ["Today"]
  if (buckets.length < 3) return [tally.window.axis(first), "Today"]
  return [tally.window.axis(first), tally.window.axis(middle), "Today"]
}

function pluralize(count: number, word: string): string {
  return `${count} ${count === 1 ? word : `${word}s`}`
}

function Pills({ range, onPick }: { range: Range; onPick: (range: Range) => void }) {
  return (
    <div className="os-pills" role="group" aria-label="Time range">
      {RANGES.map((each) => (
        <button key={each} type="button" className="os-pill max-sm:px-2" aria-pressed={each === range} onClick={() => onPick(each)}>
          {RANGE_LABELS[each]}
        </button>
      ))}
    </div>
  )
}

function Change({ tally }: { tally: Tally }) {
  const [arrow, words, up] = tally.change
  if (!words) return null
  return (
    <span className="text-lg font-semibold text-ink-2">
      {arrow && <span className={up ? "text-up" : "text-down"} aria-label={up ? "Up" : "Down"}>{arrow}</span>} {words}
    </span>
  )
}

function ChangeAfterDot({ tally }: { tally: Tally }) {
  const [arrow, words, up] = tally.change
  if (!words) return null
  return (
    <> · {arrow && <span className={up ? "text-up" : "text-down"} aria-label={up ? "Up" : "Down"}>{arrow}</span>} {words}</>
  )
}

function Headcount({ tally }: { tally: Tally }) {
  return (
    <div className="mt-0.5 flex flex-wrap items-baseline gap-x-[22px] gap-y-1.5">
      <span className="os-num os-big">{tally.totals.commits}</span>
      <Change tally={tally} />
    </div>
  )
}

function PageHeadline({ tally }: { tally: Tally }) {
  const totals = tally.totals
  const shares = tally.shares
  return (
    <div className="mt-[26px]">
      <p className="os-label">Commits · {tally.scope}, {tally.window.words}</p>
      <Headcount tally={tally} />
      {shares.length > 0 && (
        <>
          <div className="os-sharebar mt-5" role="img" aria-label="Share of commits by project">
            {shares.map(({ project, commits }) => (
              <div key={project.repo} className={`${projectClass(project.rank)} min-w-1.5 bg-(--project)`} style={{ flex: `${commits} 1 0` }}
                   title={`${project.name}: ${pluralize(commits, "commit")}`} />
            ))}
          </div>
          <div className="mt-2 flex flex-wrap gap-x-5 gap-y-1 text-[13px] text-ink-2">
            {shares.map(({ project, commits }) => (
              <span key={project.repo}><span className="os-num font-bold text-ink">{Math.round((100 * commits) / totals.commits)}%</span> {project.name}</span>
            ))}
          </div>
        </>
      )}
      <p className="os-xs os-muted mt-3">
        {totals.shipped} shipped · {totals.published} published · {pluralize(tally.projectsWithCommits, "project")} with commits · {pluralize(totals.activeDays, "active day")}
      </p>
    </div>
  )
}

function Filters({ tally, pills, onPick }: { tally: Tally; pills: ReactNode; onPick: (selected: string[]) => void }) {
  const projects = tally.data.projects
  const all = projects.map((project) => project.repo)

  function toggle(repo: string) {
    const picked = tally.filtered ? tally.selected : all
    const next = picked.includes(repo) ? picked.filter((each) => each !== repo) : [...picked, repo]
    onPick(next.length === 0 || next.length === all.length ? [] : all.filter((each) => next.includes(each)))
  }

  return (
    <div className="os-between mt-6">
      {projects.length > 1 && (
        <div role="group" aria-label="Projects" className="flex flex-wrap gap-2">
          <button type="button" className={`os-chip ${tally.filtered ? "text-ink" : ""}`} aria-pressed={!tally.filtered} onClick={() => onPick([])}>All projects</button>
          {projects.map((project) => {
            const on = !tally.filtered || tally.selected.includes(project.repo)
            return (
              <button key={project.repo} type="button" aria-pressed={on} onClick={() => toggle(project.repo)}
                      className={`os-chip ${projectClass(project.rank)} ${on ? "border-(--project) bg-(--project) text-(--on-project)" : "border-dashed"}`}>
                <span className={`os-dot ${on ? "bg-current opacity-60" : "bg-line"}`} />{project.name}
              </button>
            )
          })}
        </div>
      )}
      <div className="flex flex-wrap items-center gap-2.5">{pills}</div>
    </div>
  )
}

function Shipped({ tally, linkedId }: { tally: Tally; linkedId: number | null }) {
  const [all, setAll] = useState(false)
  const items = tally.items
  const shown = all ? items : items.slice(0, SHOWN)
  const names = new Map(tally.data.projects.map((project) => [project.repo, project.name]))
  const empty = tally.filtered ? tally.window.emptyTagged(tally.selectionName(true)) : tally.window.empty

  return (
    <>
      <div className="os-between">
        <h2 id="what-shipped" className="os-h2">What shipped</h2>
        <span className="os-xs os-muted">{items.length} {tally.window.word}</span>
      </div>
      {items.length === 0 ? (
        <p className="os-note mt-3">{empty}</p>
      ) : (
        <div className="mt-2.5">
          {shown.map((item) => <ShippedRow key={item.id} item={item} name={item.repo ? names.get(item.repo) : undefined} linked={item.id === linkedId} />)}
          {!all && items.length > SHOWN && (
            <button type="button" className="os-btn2 sm mt-3" onClick={() => setAll(true)}>Show all {items.length}</button>
          )}
        </div>
      )}
    </>
  )
}

function ShippedRow({ item, name, linked }: { item: Item; name: string | undefined; linked: boolean }) {
  return (
    <div id={linked ? undefined : `entry-${item.id}`} className="os-row os-rowflex scroll-mt-6 py-3">
      <span className="os-sm os-muted flex-[0_0_64px]">{d.short(item.date)}</span>
      <span className="os-xs flex-[0_0_84px] font-bold text-ink-3">{item.shipped ? "Shipped" : "Published"}</span>
      <span className="min-w-0 flex-[1_1_300px] text-[15px] font-semibold">
        {item.url ? <a href={`/e/${item.id}/out`} target="_blank" rel="noopener" data-turbo="false" className="hover:underline" title={item.url}>{item.title}</a> : item.title}
        {item.runIn && <span className="font-normal text-ink-3">{item.runIn}</span>}
      </span>
      {name && <span className="os-xs os-muted">{name}</span>}
    </div>
  )
}
