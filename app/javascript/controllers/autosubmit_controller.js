import { Controller } from "@hotwired/stimulus"

// Re-renders the picker server-side whenever a box is ticked, so the preview is
// built by the same Ruby formatter as the rake task and the future email.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
