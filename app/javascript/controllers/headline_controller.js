import { Controller } from "@hotwired/stimulus"

// A suggestion is a starting point for the day's headline, never the headline
// itself: it fills the box and leaves the cursor there to rewrite it.
export default class extends Controller {
  static targets = ["input"]

  use({ params: { text } }) {
    const input = this.inputTarget
    input.value = String(text).slice(0, Number(input.maxLength) || 80)
    input.focus()
    input.setSelectionRange(input.value.length, input.value.length)
    input.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
