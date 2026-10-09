import { Controller } from "@hotwired/stimulus"

// Reloads a loaded Turbo frame when the page comes back into view. The browser's
// back button can restore Settings from its cache after a trip to GitHub, and a
// builder may change repos on GitHub in another tab, so the GitHub repos list
// would otherwise show what it was before. Each load asks GitHub, so a frame
// that is hidden, or reloaded in the last few seconds, is left alone.
export default class extends Controller {
  static values = { minInterval: { type: Number, default: 5000 } }

  connect() {
    this.onPageShow = (event) => { if (event.persisted) this.reload() }
    this.onVisibilityChange = () => { if (document.visibilityState === "visible") this.reload() }
    window.addEventListener("pageshow", this.onPageShow)
    document.addEventListener("visibilitychange", this.onVisibilityChange)
  }

  disconnect() {
    window.removeEventListener("pageshow", this.onPageShow)
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
  }

  reload() {
    const loaded = this.element.hasAttribute("complete")
    const visible = this.element.offsetParent !== null
    const recent = this.lastReload && Date.now() - this.lastReload < this.minIntervalValue
    if (!loaded || !visible || recent) return

    this.lastReload = Date.now()
    this.element.reload()
  }
}
