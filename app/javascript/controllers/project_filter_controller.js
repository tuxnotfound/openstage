import { Controller } from "@hotwired/stimulus"

// The project menu on the progress section: ticks apply together when the
// menu closes, by its button, an outside click or Escape, and only if they
// changed, so picking three projects reloads the page once.
export default class extends Controller {
  static targets = ["form"]

  toggled() {
    if (this.element.open) {
      this.opened = this.ticked()
    } else if (this.opened !== undefined && this.ticked() !== this.opened) {
      this.formTarget.requestSubmit()
    }
  }

  ticked() {
    return [...this.formTarget.querySelectorAll("input[type=checkbox]:checked")].map((box) => box.value).join("\n")
  }
}
