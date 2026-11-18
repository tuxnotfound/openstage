import type { ProgressRange, Tab, TabLink } from "../types"
import { written } from "../filter/lines"

// The analytics page's tabs: a link each, so each tab is a page of its own,
// which Turbo visits; the current one marked. A link keeps the window and
// the projects in view, and leaves the numbers drawn to the tab, which
// opens on its own. On Free, the tabs Pro opens wear its mark. On a phone
// they scroll sideways.

type Props = { tabs: TabLink[]; current: Tab; range: ProgressRange | null; projects: string[]; defaultRange: ProgressRange }

export default function AnalyticsTabs({ tabs, current, range, projects, defaultRange }: Props) {
  return (
    <nav aria-label="Analytics" className="flex gap-x-[30px] overflow-x-auto border-b border-line [scrollbar-width:none] max-[900px]:gap-x-[22px]">
      {tabs.map((tab) => {
        const on = tab.key === current
        return (
          <a key={tab.key} href={tabHref(tab.path, range, projects, defaultRange)} aria-current={on ? "page" : undefined}
             className={`inline-flex h-11 flex-none items-center text-[15px] font-bold whitespace-nowrap no-underline ${on ? "text-ink shadow-[inset_0_-3px_0_var(--color-accent)]" : "text-ink-3 hover:text-ink"}`}>
            {tab.label}
            {tab.pro && <span className="os-tag pro ml-2 h-5 px-2 text-[11px]">✦ Pro</span>}
          </a>
        )
      })}
    </nav>
  )
}

// A tab's address with the window and the projects in view, each left out
// at the page's default. range: null on a tab with no window.
export function tabHref(path: string, range: ProgressRange | null, projects: string[], defaultRange: ProgressRange): string {
  const url = new URL(path, "http://openstage.invalid")
  if (range && range !== defaultRange) url.searchParams.set("range", range)
  if (projects.length > 0) url.searchParams.set("projects", projects.join(","))
  return written(url)
}
