import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: String }

  connect() {
    if (!this.activeValue && this.tabTargets.length > 0) {
      this.activeValue = this.tabTargets[0].dataset.tabsTab
    }
    this.update()
  }

  show(event) {
    this.activeValue = event.currentTarget.dataset.tabsTab
  }

  activeValueChanged() {
    this.update()
  }

  update() {
    this.tabTargets.forEach(tab => {
      const active = tab.dataset.tabsTab === this.activeValue
      tab.dataset.active = active ? "true" : "false"
    })
    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.dataset.tabsPanel !== this.activeValue)
    })
  }
}
