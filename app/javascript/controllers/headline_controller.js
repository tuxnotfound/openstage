import { Controller } from "@hotwired/stimulus"

// A commit or post picked from the day's menu is a starting point for the
// day's words, never the words themselves: it fills the box and leaves the
// cursor there to rewrite it. The menu then goes back to its prompt.
export default class extends Controller {
  static targets = ["input"]

  pick(event) {
    const menu = event.currentTarget
    if (!menu.value) return

    const input = this.inputTarget
    input.value = menu.value.slice(0, Number(input.maxLength) || 80)
    menu.selectedIndex = 0
    input.focus()
    input.setSelectionRange(input.value.length, input.value.length)
    input.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
