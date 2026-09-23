import { Controller } from "@hotwired/stimulus"

// The generated recap is only a starting point. This keeps the counter, the
// copy button, the compose links and the "Posted it?" form pointed at whatever
// the builder actually typed, and warns before a pick change rebuilds the text.
export default class extends Controller {
  static targets = ["editor", "counter", "intent", "logText", "copyButton", "resetButton"]
  static values = { limit: Number, trackUrl: String }

  connect() {
    if (!this.hasEditorTarget) return
    this.generated = this.editorTarget.value
  }

  get dirty() {
    return this.hasEditorTarget && this.editorTarget.value !== this.generated
  }

  update() {
    const text = this.editorTarget.value
    const length = [...text].length
    const over = length > this.limitValue

    this.counterTarget.textContent = `${length} / ${this.limitValue}${over ? " — over limit" : ""}`
    this.counterTarget.classList.toggle("text-red-600", over)
    this.counterTarget.classList.toggle("text-gray-400", !over)
    this.editorTarget.classList.toggle("border-red-300", over)
    this.editorTarget.classList.toggle("border-gray-200", !over)

    this.intentTargets.forEach((link) => {
      link.href = link.dataset.base + encodeURIComponent(text)
    })
    // Follows the editor until the log text is edited by hand, then stops.
    if (this.hasLogTextTarget && !this.logTextTarget.dataset.touched) this.logTextTarget.value = text
    if (this.hasResetButtonTarget) this.resetButtonTarget.hidden = !this.dirty
  }

  touchLog() {
    this.logTextTarget.dataset.touched = "1"
  }

  reset() {
    this.editorTarget.value = this.generated
    this.update()
  }

  copy() {
    this.report("recap_copied")
    navigator.clipboard.writeText(this.editorTarget.value)
      .then(() => this.flash("Copied"))
      .catch(() => this.flash("Press Cmd+C"))
  }

  // Runs before autosubmit on the same event. A pick change re-renders the
  // page, which would silently throw away hand-written text.
  guard(event) {
    if (!this.dirty) return
    if (window.confirm("Changing your picks rebuilds the text and discards your edits. Continue?")) return

    event.stopImmediatePropagation()
    const input = event.target
    if (input.type === "radio") {
      const form = input.form
      form.querySelectorAll(`input[name="${input.name}"]`).forEach((radio) => {
        radio.checked = radio.defaultChecked
      })
    } else {
      input.checked = !input.checked
    }
  }

  // The compose links open a new tab, so the report must not block the click.
  intent(event) {
    this.report("recap_intent", event.currentTarget.dataset.network)
  }

  report(name, detail = "") {
    if (!this.trackUrlValue) return
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.trackUrlValue, {
      method: "POST",
      keepalive: true,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({ name, detail })
    }).catch(() => {})
  }

  flash(message) {
    const button = this.copyButtonTarget
    const original = button.textContent
    button.textContent = message
    setTimeout(() => { button.textContent = original }, 1500)
  }
}
