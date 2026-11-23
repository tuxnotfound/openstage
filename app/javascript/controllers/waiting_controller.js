import { Controller } from "@hotwired/stimulus"

// The second thing a form's button says while its answer is on the way.
// Turbo shows the first as the form goes (data-turbo-submits-with) and puts
// the button's own words back when the answer comes; this one follows the
// first after a moment, for a wait with two parts to name.
export default class extends Controller {
  static values = { then: String, after: { type: Number, default: 1000 } }

  start({ detail: { formSubmission } }) {
    const button = formSubmission.submitter
    if (!button) return

    this.timer = setTimeout(() => { button.textContent = this.thenValue }, this.afterValue)
  }

  stop() {
    clearTimeout(this.timer)
  }

  disconnect() {
    this.stop()
  }
}
