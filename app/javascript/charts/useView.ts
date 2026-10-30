import { useEffect, useLayoutEffect, useRef, useState } from "react"
import { marked, ours } from "./history"
import { ViewStore } from "./viewStore"

// The view an island shows, and the way to another: the current one stays on
// screen until the next arrives, marked busy only when that takes a moment;
// only the latest click lands; and the page's URL follows once it shows,
// written from the view that landed (page), with anything the island keeps
// beside the view (landed). A view either takes the place of the one before
// in the browser's history (replace) or follows it (push), so Back shows the
// one before again, in place (history.ts); a view Back or Forward brings
// back hands itself to restored.
const BUSY_AFTER_MS = 150

// A view to show on click, and to warm when the pointer or focus reaches it.
export type Target = { go: () => void; warm: () => void }

export type Write = "push" | "replace" | "none"

// own: the page's params the island's views name; restored: what a view
// brought back by Back or Forward also sets.
export type ViewOptions<T> = { own: string[]; restored: (view: T) => void }

type Ask<T> = { url: string; page: (next: T) => string; landed?: (next: T) => void; write: Write }

export function useView<T>(initial: T, initialUrl: string, { own, restored }: ViewOptions<T>) {
  const [store] = useState(() => {
    const views = new ViewStore<T>()
    views.seed(initialUrl, initial)
    return views
  })
  const [mark] = useState(() => Math.random().toString(36).slice(2))
  const [view, setView] = useState(initial)
  const [busy, setBusy] = useState(false)
  const [failed, setFailed] = useState<Ask<T> | null>(null)
  const latest = useRef(0)
  // The view on screen's address, and the page's address as the island last saw it.
  const shown = useRef(initialUrl)
  const here = useRef("")
  const back = useRef(restored)
  useLayoutEffect(() => { back.current = restored })

  function open(url: string, page: (next: T) => string, landed?: (next: T) => void, write: Write = "replace") {
    const request = ++latest.current
    setFailed(null)
    const slow = window.setTimeout(() => { if (latest.current === request) setBusy(true) }, BUSY_AFTER_MS)
    store.get(url)
      .then((next) => {
        if (latest.current !== request) return
        setView(next)
        landed?.(next)
        if (write === "none") shown.current = url
        else remember(url, page(next), write === "push")
      })
      .catch(() => { if (latest.current === request) setFailed({ url, page, landed, write }) })
      .finally(() => {
        window.clearTimeout(slow)
        if (latest.current === request) setBusy(false)
      })
  }

  // A new entry keeps the one it follows marked with the view that entry showed.
  function remember(url: string, address: string, push: boolean) {
    const target = new URL(address, window.location.href).href
    const state = window.history.state as unknown
    if (push && target !== window.location.href) {
      window.history.replaceState(marked(state, { page: mark, url: shown.current }), "", window.location.href)
      window.history.pushState(marked(state, { page: mark, url }), "", target)
    } else {
      window.history.replaceState(marked(state, { page: mark, url }), "", target)
    }
    shown.current = url
    here.current = window.location.href
  }

  // Back and Forward over the island's own entries show their views in
  // place, before Turbo would visit the page anew; a Turbo frame that moves
  // the address on leaves its entries to Turbo.
  useEffect(() => {
    here.current = window.location.href
    const popped = (event: PopStateEvent) => {
      const entry = ours(event.state, mark, window.location.href, here.current, own)
      if (!entry) return
      event.stopImmediatePropagation()
      here.current = window.location.href
      open(entry.url, () => window.location.href, (next) => back.current(next), "none")
    }
    const moved = () => { here.current = window.location.href }
    window.addEventListener("popstate", popped, true)
    document.addEventListener("turbo:frame-load", moved)
    return () => {
      window.removeEventListener("popstate", popped, true)
      document.removeEventListener("turbo:frame-load", moved)
    }
    // Once per mount: the store, the setters and the refs it reads stay.
  }, [])

  // Ask again, past every view kept, after a change on the server.
  function reload(url: string, page: (next: T) => string, landed?: (next: T) => void, write: Write = "replace") {
    store.clear()
    open(url, page, landed, write)
  }

  return {
    view,
    busy,
    failed: failed !== null,
    open,
    reload,
    retry: () => failed && open(failed.url, failed.page, failed.landed, failed.write),
    prefetch: (url: string) => store.prefetch(url),
  }
}
