import { Controller } from "@hotwired/stimulus"

// Copies a field's text. With a track URL and an event, a copy that worked
// is reported, once per builder per day.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { trackUrl: String, event: String, detail: String }

  copy() {
    const source = this.sourceTarget
    const text = ["INPUT", "TEXTAREA"].includes(source.tagName) ? source.value : source.textContent

    navigator.clipboard.writeText(text)
      .then(() => { this.flash("Copied"); this.report() })
      .catch(() => this.flash("Press Cmd+C"))
  }

  flash(message) {
    if (!this.hasButtonTarget) return

    const button = this.buttonTarget
    const original = button.textContent
    button.textContent = message
    setTimeout(() => { button.textContent = original }, 1500)
  }

  report() {
    if (!this.trackUrlValue || !this.eventValue) return

    fetch(this.trackUrlValue, {
      method: "POST",
      keepalive: true,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content },
      body: JSON.stringify({ name: this.eventValue, detail: this.detailValue })
    }).catch(() => {})
  }
}
