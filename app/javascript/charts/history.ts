// An island's own entries in the browser's history. Each entry it writes
// carries a mark: which island wrote it (page, new on every mount) and the
// API address of the view it showed (url), so Back and Forward show that
// view again in place. An entry another island wrote, or one whose address
// differs outside the island's own params (a Turbo frame moved on in
// between), is Turbo's to restore.

export type Mark = { page: string; url: string }

type State = Record<string, unknown>

// The state an entry keeps, Turbo's included, with an island's mark.
export function marked(state: unknown, mark: Mark): State {
  return { ...(isState(state) ? state : {}), chart: mark }
}

export function markOf(state: unknown): Mark | null {
  const mark = isState(state) ? state.chart : null
  return isState(mark) && typeof mark.page === "string" && typeof mark.url === "string" ? { page: mark.page, url: mark.url } : null
}

// A page's address without the params an island owns, so two addresses
// that differ only in its view read the same.
export function outside(href: string, own: string[]): string {
  const url = new URL(href)
  own.forEach((key) => url.searchParams.delete(key))
  url.searchParams.sort()
  return `${url.pathname}?${url.searchParams.toString()}`
}

// Whether a popped entry is an island's to show: its own mark, and the
// rest of the page's address where the island left it.
export function ours(state: unknown, page: string, href: string, here: string, own: string[]): Mark | null {
  const mark = markOf(state)
  return mark && mark.page === page && outside(href, own) === outside(here, own) ? mark : null
}

function isState(value: unknown): value is State {
  return typeof value === "object" && value !== null
}
