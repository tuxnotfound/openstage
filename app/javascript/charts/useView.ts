import { useRef, useState } from "react"
import { ViewStore } from "./viewStore"

// The view an island shows, and the way to another: the current one stays on
// screen until the next arrives, marked busy only when that takes a moment;
// only the latest click lands; and the page's URL follows once it shows,
// written from the view that landed (page), with anything the island keeps
// beside the view (landed).
const BUSY_AFTER_MS = 150

// A view to show on click, and to warm when the pointer or focus reaches it.
export type Target = { go: () => void; warm: () => void }

type Ask<T> = { url: string; page: (next: T) => string; landed?: (next: T) => void }

export function useView<T>(initial: T, initialUrl: string) {
  const [store] = useState(() => {
    const views = new ViewStore<T>()
    views.seed(initialUrl, initial)
    return views
  })
  const [view, setView] = useState(initial)
  const [busy, setBusy] = useState(false)
  const [failed, setFailed] = useState<Ask<T> | null>(null)
  const latest = useRef(0)

  function open(url: string, page: (next: T) => string, landed?: (next: T) => void) {
    const request = ++latest.current
    setFailed(null)
    const slow = window.setTimeout(() => { if (latest.current === request) setBusy(true) }, BUSY_AFTER_MS)
    store.get(url)
      .then((next) => {
        if (latest.current !== request) return
        setView(next)
        landed?.(next)
        window.history.replaceState(window.history.state, "", page(next))
      })
      .catch(() => { if (latest.current === request) setFailed({ url, page, landed }) })
      .finally(() => {
        window.clearTimeout(slow)
        if (latest.current === request) setBusy(false)
      })
  }

  // Ask again, past every view kept, after a change on the server.
  function reload(url: string, page: (next: T) => string, landed?: (next: T) => void) {
    store.clear()
    open(url, page, landed)
  }

  return {
    view,
    busy,
    failed: failed !== null,
    open,
    reload,
    retry: () => failed && open(failed.url, failed.page, failed.landed),
    prefetch: (url: string) => store.prefetch(url),
  }
}
