import { Controller } from "@hotwired/stimulus"

// Reloads a loaded Turbo frame whenever it comes back into view, so the GitHub
// repos list in Settings shows what GitHub says now. That covers the tab being
// shown again, the browser's back button after a trip to GitHub, Turbo's own
// page cache, and repos changed on GitHub in another browser tab. Turbo itself
// does the first load (loading: lazy). Each load asks GitHub, so a frame that is
// hidden, or loaded in the last few seconds, is left alone.
export default class extends Controller {
  static values = { minInterval: { type: Number, default: 5000 } }

  connect() {
    this.onLoad = () => { this.lastLoad = Date.now() }
    this.onPageShow = (event) => { if (event.persisted) this.reload() }
    this.onVisibilityChange = () => { if (document.visibilityState === "visible") this.reload() }
    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) this.reload()
    })

    this.element.addEventListener("turbo:frame-load", this.onLoad)
    window.addEventListener("pageshow", this.onPageShow)
    document.addEventListener("visibilitychange", this.onVisibilityChange)
    this.observer.observe(this.element)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.onLoad)
    window.removeEventListener("pageshow", this.onPageShow)
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    this.observer.disconnect()
  }

  reload() {
    const loaded = this.element.hasAttribute("complete")
    const preview = document.documentElement.hasAttribute("data-turbo-preview")
    const visible = this.element.offsetParent !== null
    const recent = this.lastLoad && Date.now() - this.lastLoad < this.minIntervalValue
    if (!loaded || preview || !visible || recent) return

    this.lastLoad = Date.now()
    this.element.reload()
  }
}
