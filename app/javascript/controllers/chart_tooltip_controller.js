import { Controller } from "@hotwired/stimulus"

// A hovered target either names a <template> the server rendered with the
// whole tooltip (data-chart-tooltip-template-param), or carries a count and a
// date to write one.
export default class extends Controller {
  static targets = ["tooltip"]

  // The tooltip keeps its place in pixels, so it closes when the window's
  // width changes: left open as a desktop narrowed to a phone's width, it ran
  // past the page's edge. The height alone never closes it, as a phone's
  // address bar changes the height while the page scrolls. The charts' own
  // tooltip does the same (charts/filter/widthChange.ts).
  connect() {
    this.width = window.innerWidth
    this.closeOnWidthChange = () => {
      if (window.innerWidth === this.width) return
      this.width = window.innerWidth
      this.hide()
    }
    window.addEventListener("resize", this.closeOnWidthChange)
  }

  disconnect() {
    window.removeEventListener("resize", this.closeOnWidthChange)
  }

  show(event) {
    const template = event.params.template && document.getElementById(event.params.template)
    if (template) {
      this.tooltipTarget.replaceChildren(template.content.cloneNode(true))
    } else {
      const t = event.currentTarget
      const count = t.dataset.count
      const date  = t.dataset.date
      const label = t.dataset.label || (count === "1" ? "view" : "views")
      this.tooltipTarget.innerHTML =
        `<div class="font-medium">${count} ${label}</div>` +
        `<div class="text-gray-300">${date}</div>`
    }
    this.tooltipTarget.classList.remove("hidden")
    this.position(event)
  }

  move(event) {
    if (this.tooltipTarget.classList.contains("hidden")) return
    this.position(event)
  }

  hide() {
    this.tooltipTarget.classList.add("hidden")
  }

  position(event) {
    const box = this.element.getBoundingClientRect()
    const x = event.clientX - box.left
    const y = event.clientY - box.top
    const tipW = this.tooltipTarget.offsetWidth  || 100
    const tipH = this.tooltipTarget.offsetHeight || 40
    const left = Math.max(4, Math.min(x - tipW / 2, box.width - tipW - 4))
    const top  = Math.max(4, y - tipH - 10)
    this.tooltipTarget.style.left = `${left}px`
    this.tooltipTarget.style.top  = `${top}px`
  }
}
