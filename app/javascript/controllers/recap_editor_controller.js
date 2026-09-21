import { Controller } from "@hotwired/stimulus"

// The generated recap is only a starting point. This keeps the counter, the
// copy button, the compose links and the "Posted it?" form pointed at whatever
// the builder actually typed, and warns before a pick change rebuilds the text.
export default class extends Controller {
  static targets = ["editor", "counter", "intent", "logText", "copyButton", "resetButton"]
  static values = { limit: Number }

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
    if (this.hasLogTextTarget) this.logTextTarget.value = text
    if (this.hasResetButtonTarget) this.resetButtonTarget.hidden = !this.dirty
  }

  reset() {
    this.editorTarget.value = this.generated
    this.update()
  }

  copy() {
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

  flash(message) {
    const button = this.copyButtonTarget
    const original = button.textContent
    button.textContent = message
    setTimeout(() => { button.textContent = original }, 1500)
  }
}
