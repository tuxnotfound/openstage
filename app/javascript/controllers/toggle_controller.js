import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // trigger: the button that opens it, told whether it is open.
  static targets = ["content", "openIcon", "closeIcon", "trigger"]
  static values = { open: Boolean }

  connect() {
    this.update()
  }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.update()
  }

  update() {
    if (this.hasContentTarget) {
      this.contentTargets.forEach(t => t.classList.toggle("hidden", !this.openValue))
    }
    if (this.hasOpenIconTarget) {
      this.openIconTargets.forEach(t => t.classList.toggle("hidden", this.openValue))
    }
    if (this.hasCloseIconTarget) {
      this.closeIconTargets.forEach(t => t.classList.toggle("hidden", !this.openValue))
    }
    this.triggerTargets.forEach(t => t.setAttribute("aria-expanded", String(this.openValue)))
  }
}
