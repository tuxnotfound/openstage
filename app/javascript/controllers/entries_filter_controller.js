import { Controller } from "@hotwired/stimulus"

// The dashboard's entry filters, one set for every tab. The tabs and lists
// redraw in their frame as the builder types (after a pause) or picks a type
// or repo, and the URL follows, with the tab shown (the tabs controller on
// the same element), so a reload or Back shows the same list: a new search
// or a pick adds a step to Back, and the keys typed after it only replace
// that step. The form is never redrawn, so the field keeps its focus and
// caret. A row's buttons carry the filters as they are now, so the lists a
// click redraws stay filtered. Without JavaScript the form is a plain GET.
export default class extends Controller {
  static targets = ["form", "clear", "tab"]
  static values = { delay: { type: Number, default: 250 } }

  disconnect() {
    clearTimeout(this.timer)
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.submit(this.searching ? "replace" : "advance")
      this.searching = true
    }, this.delayValue)
  }

  change() {
    this.submit("advance")
  }

  clear(event) {
    event.preventDefault()
    for (const name of ["q", "type", "repo"]) {
      const field = this.formTarget.elements.namedItem(name)
      if (field) field.value = ""
    }
    this.submit("advance")
  }

  carry(event) {
    const form = event.target
    if (!this.hasFormTarget || form === this.formTarget || !(form instanceof HTMLFormElement)) return

    for (const name of ["q", "type", "repo"]) {
      const carried = form.querySelector(`input[type="hidden"][name="${name}"]`)
      const field = this.formTarget.elements.namedItem(name)
      if (carried) carried.value = field ? field.value : ""
    }
  }

  // Blank fields and the default tab stay out of the URL: Turbo reads the
  // form as the submit event fires, so they are switched off only for it,
  // all but the field being typed in, which switching off would blur.
  submit(action) {
    clearTimeout(this.timer)
    if (action === "advance") this.searching = false
    this.formTarget.dataset.turboAction = action
    if (this.hasTabTarget && this.element.dataset.tabsActiveValue) this.tabTarget.value = this.element.dataset.tabsActiveValue
    if (this.hasClearTarget) this.clearTarget.hidden = !this.filtering()

    const left = Array.from(this.formTarget.elements).filter(field => field.name && !field.disabled && field !== document.activeElement &&
      (field.value === "" || field.value === field.dataset.entriesFilterDefault))
    left.forEach(field => { field.disabled = true })
    this.formTarget.requestSubmit()
    left.forEach(field => { field.disabled = false })
  }

  filtering() {
    return ["q", "type", "repo"].some(name => {
      const field = this.formTarget.elements.namedItem(name)
      return field && field.value.trim() !== ""
    })
  }
}
