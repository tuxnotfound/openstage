import { Controller } from "@hotwired/stimulus"

// The dashboard's entry box: one line until the builder is in it, then the
// kinds and every field, which stay open once opened.
export default class extends Controller {
  open() {
    this.element.classList.add("open")
  }
}
