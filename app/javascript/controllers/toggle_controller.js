import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "openIcon", "closeIcon"]
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
  }
}
