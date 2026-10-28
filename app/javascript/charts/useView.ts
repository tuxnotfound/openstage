import { useRef, useState } from "react"
import { ViewStore } from "./viewStore"

// The view an island shows, and the way to another: the current one stays on
// screen until the next arrives, marked busy only when that takes a moment;
// only the latest click lands; and the page's URL follows once it shows,
// with anything the island keeps beside the view (landed).
const BUSY_AFTER_MS = 150

export function useView<T>(initial: T, initialUrl: string) {
  const [store] = useState(() => {
    const views = new ViewStore<T>()
    views.seed(initialUrl, initial)
    return views
  })
  const [view, setView] = useState(initial)
  const [busy, setBusy] = useState(false)
  const [failed, setFailed] = useState<{ url: string; pageUrl: string; landed?: () => void } | null>(null)
  const latest = useRef(0)

  function show(url: string, pageUrl: string, landed?: () => void) {
    const request = ++latest.current
    setFailed(null)
    const slow = window.setTimeout(() => { if (latest.current === request) setBusy(true) }, BUSY_AFTER_MS)
    store.get(url)
      .then((next) => {
        if (latest.current !== request) return
        setView(next)
        landed?.()
        window.history.replaceState(window.history.state, "", pageUrl)
      })
      .catch(() => { if (latest.current === request) setFailed({ url, pageUrl, landed }) })
      .finally(() => {
        window.clearTimeout(slow)
        if (latest.current === request) setBusy(false)
      })
  }

  // Ask again, past every view kept, after a change on the server.
  function reload(url: string, pageUrl: string, landed?: () => void) {
    store.clear()
    show(url, pageUrl, landed)
  }

  return {
    view,
    busy,
    failed: failed !== null,
    show,
    reload,
    retry: () => failed && show(failed.url, failed.pageUrl, failed.landed),
    prefetch: (url: string) => store.prefetch(url),
  }
}
