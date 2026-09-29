import { Controller } from "@hotwired/stimulus"

// A native <details> menu only closes from its own summary. This closes it on
// an outside click or Escape, and before Turbo caches the page, so a menu left
// open is not restored open on Back.
export default class extends Controller {
  connect() {
    this.onClick = this.onClick.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
    this.close = this.close.bind(this)
    document.addEventListener("click", this.onClick)
    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("turbo:before-cache", this.close)
  }

  disconnect() {
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("turbo:before-cache", this.close)
  }

  onClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  close() {
    this.element.open = false
  }
}
