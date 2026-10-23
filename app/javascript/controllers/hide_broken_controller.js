import { Controller } from "@hotwired/stimulus"

// A picture whose address no longer answers leaves no empty box behind. It
// may have failed before this connected, so connect checks too.
export default class extends Controller {
  connect() {
    if (this.element.complete && this.element.naturalWidth === 0) this.hide()
  }

  hide() {
    this.element.remove()
  }
}
