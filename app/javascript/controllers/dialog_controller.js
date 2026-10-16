import { Controller } from "@hotwired/stimulus"

// A native <dialog> as a modal: its button opens it, and Escape, the close
// button or a click on the backdrop shut it.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
