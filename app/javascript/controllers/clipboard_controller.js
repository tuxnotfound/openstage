import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    const text = this.sourceTarget.textContent

    navigator.clipboard.writeText(text)
      .then(() => this.flash("Copied"))
      .catch(() => this.flash("Press Cmd+C"))
  }

  flash(message) {
    if (!this.hasButtonTarget) return

    const button = this.buttonTarget
    const original = button.textContent
    button.textContent = message
    setTimeout(() => { button.textContent = original }, 1500)
  }
}
