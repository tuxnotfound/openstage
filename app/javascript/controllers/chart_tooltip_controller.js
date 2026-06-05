import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tooltip"]

  show(event) {
    const t = event.currentTarget
    const count = t.dataset.count
    const date  = t.dataset.date
    const label = t.dataset.label || (count === "1" ? "view" : "views")
    this.tooltipTarget.innerHTML =
      `<div class="font-medium">${count} ${label}</div>` +
      `<div class="text-gray-300">${date}</div>`
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
