import { Controller } from "@hotwired/stimulus"

// A project's picture. Its box pulses while the picture loads (data-loading,
// set by the server), so a slow one reads as coming rather than as a blank
// box. A picture whose address no longer answers leaves no empty box behind.
// Either may have happened before this connected, so connect checks too.
export default class extends Controller {
  connect() {
    if (!this.element.complete) return
    if (this.element.naturalWidth === 0) this.broken()
    else this.loaded()
  }

  loaded() {
    delete this.element.dataset.loading
  }

  broken() {
    this.element.remove()
  }
}
