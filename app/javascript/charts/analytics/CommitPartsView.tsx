import { Fragment } from "react"
import { MarkIcon } from "../filter/Marks"
import type { CommitParts, NewsItem } from "../types"

// The Commits tab's parts under its chart, a panel each, side by side where
// both fit. When you commit: a cell per weekday and hour, Monday first,
// darker with more commits, each saying its count on hover, with its key
// from Fewer to More. What's new: the window's entries for the projects in
// view, newest first, each with its mark in its project's colour, then its
// project and day; the first eight, the rest behind Show all, which a mark
// on the chart opens to reach its row (Marks.reveal).

const PANEL = "os-panel p-[clamp(16px,1.7vw,24px)]"
const SHOWN = 8
const HEAT = ["bg-line", "bg-heat-1", "bg-heat-2", "bg-heat-3", "bg-heat-4"]
const HOURS = ["00:00", "06:00", "12:00", "18:00"]

export default function CommitPartsView({ commits, words }: { commits: CommitParts; words: string }) {
  return (
    <div className="grid grid-cols-[repeat(auto-fit,minmax(min(100%,460px),1fr))] gap-4">
      <Hours hours={commits.hours} words={words} />
      <News news={commits.news} empty={commits.newsEmpty} />
    </div>
  )
}

function Hours({ hours, words }: { hours: CommitParts["hours"]; words: string }) {
  return (
    <section className={PANEL} aria-labelledby="when-you-commit">
      <div className="flex items-baseline justify-between gap-3">
        <h2 id="when-you-commit" className="os-h3">When you commit</h2>
        <span className="flex items-center gap-1 text-xs text-ink-3" aria-hidden="true">
          Fewer {HEAT.map((css) => <i key={css} className={`size-3 rounded-[3px] ${css}`} />)} More
        </span>
      </div>
      <div role="img" aria-label={`Commits by weekday and hour, ${words}`}
           className="mt-3.5 grid grid-cols-[34px_repeat(24,minmax(0,1fr))] items-center gap-[3px] max-[900px]:grid-cols-[30px_repeat(24,minmax(0,1fr))] max-[900px]:gap-0.5">
        {hours.map((day) => (
          <Fragment key={day.name}>
            <span className="text-xs leading-none text-ink-3">{day.name}</span>
            {day.cells.map((cell, hour) => <span key={hour} title={cell.title} className={`aspect-square max-h-[22px] rounded ${HEAT[cell.step]}`} />)}
          </Fragment>
        ))}
        <span />
        {HOURS.map((label) => <span key={label} className="col-span-6 pt-[3px] text-[11px] leading-none whitespace-nowrap text-ink-3">{label}</span>)}
      </div>
    </section>
  )
}

function News({ news, empty }: { news: NewsItem[]; empty: string }) {
  return (
    <section className={PANEL} aria-labelledby="whats-new">
      <h2 id="whats-new" className="os-h3">What's new</h2>
      {news.length === 0 ? <p className="os-note mt-2.5">{empty}</p> : (
        <>
          <ul className="mt-2 flex flex-col">
            {news.slice(0, SHOWN).map((item) => <NewsLine key={item.id} item={item} css="first:border-t-0" />)}
          </ul>
          {news.length > SHOWN && (
            <details className="group/all">
              <summary className="os-btn2 sm mt-3 list-none group-open/all:hidden [&::-webkit-details-marker]:hidden">Show all {news.length}</summary>
              <ul className="flex flex-col">
                {news.slice(SHOWN).map((item) => <NewsLine key={item.id} item={item} css="" />)}
              </ul>
            </details>
          )}
        </>
      )}
    </section>
  )
}

function NewsLine({ item, css }: { item: NewsItem; css: string }) {
  return (
    <li id={`entry-${item.id}`} className={`flex scroll-mt-6 items-center gap-3 border-t border-line py-2.5 text-sm ${css}`}>
      <span className={`${item.colorClass} inline-flex size-[22px] flex-none items-center justify-center rounded-full bg-(--project) text-(--on-project)`}
            title={item.kind} aria-hidden="true">
        <MarkIcon badge={item.badge} className="size-[13px]" />
      </span>
      <span className="min-w-0 flex-auto truncate font-semibold"><span className="sr-only">{item.kind}: </span>{item.title}</span>
      <span className="flex-none text-[13px] whitespace-nowrap text-ink-3">{item.project ? `${item.project} · ${item.date}` : item.date}</span>
    </li>
  )
}
