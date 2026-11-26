import { Controller } from "@hotwired/stimulus"

// The page's messages (layouts/_flash): Dismiss takes one away, and the
// last one takes the list with it, so nothing empty stays stuck to the
// top of the screen.
export default class extends Controller {
  static targets = ["message"]

  dismiss(event) {
    event.currentTarget.closest("[data-flash-target='message']").remove()
    if (!this.hasMessageTarget) this.element.remove()
  }
}
