import { Controller } from "@hotwired/stimulus"

// A card that opens one page from anywhere on it, its chart included, so the
// chart keeps its tooltips; a link inside it opens its own. The card's own
// link names the page for the keyboard and screen readers. A click with a
// modifier opens a new tab, and a click that ends a text selection opens
// nothing.
export default class extends Controller {
  static values = { url: String }

  open(event) {
    if (event.target.closest("a, button, input")) return
    if (window.getSelection()?.toString()) return

    if (event.metaKey || event.ctrlKey || event.shiftKey || event.button === 1) {
      window.open(this.urlValue, "_blank", "noopener")
    } else {
      window.Turbo ? window.Turbo.visit(this.urlValue) : window.location.assign(this.urlValue)
    }
  }
}
