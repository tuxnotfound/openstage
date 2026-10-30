import { Controller } from "@hotwired/stimulus"

// Shows one panel per tab. A tab may be a link to the page with that tab
// open, so it works without JavaScript; here it switches in place. With a
// param, the URL keeps the tab, so a reload opens it again. Tabs redrawn by a
// Turbo Stream keep the one shown, or fall back to the first once it is gone.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: String, param: String }

  connect() {
    if (!this.activeValue && this.tabTargets.length > 0) {
      this.activeValue = this.tabTargets[0].dataset.tabsTab
    }
    this.update()
  }

  show(event) {
    event.preventDefault()
    this.activeValue = event.currentTarget.dataset.tabsTab
  }

  activeValueChanged() {
    this.update()
    this.remember()
  }

  tabTargetConnected() {
    this.update()
  }

  panelTargetConnected() {
    this.update()
  }

  update() {
    const keys = this.tabTargets.map(tab => tab.dataset.tabsTab)
    if (keys.length > 0 && !keys.includes(this.activeValue)) {
      this.activeValue = keys[0]
      return
    }

    this.tabTargets.forEach(tab => {
      const active = tab.dataset.tabsTab === this.activeValue
      tab.dataset.active = active ? "true" : "false"
      tab.setAttribute("aria-selected", active ? "true" : "false")
    })
    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.dataset.tabsPanel !== this.activeValue)
    })
  }

  // Replaces the URL in place: a tab is not a step Back should retrace.
  remember() {
    if (!this.paramValue || !this.activeValue) return

    const url = new URL(window.location.href)
    const first = this.tabTargets[0]?.dataset.tabsTab
    if (this.activeValue === first) url.searchParams.delete(this.paramValue)
    else url.searchParams.set(this.paramValue, this.activeValue)
    if (url.href === window.location.href) return

    window.history.replaceState(window.history.state, "", url)
  }
}
