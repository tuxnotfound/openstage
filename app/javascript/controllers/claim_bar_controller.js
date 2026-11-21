import { Controller } from "@hotwired/stimulus"

// The preview's claim bar (previews/_bar): at the foot of the window once
// the projects have scrolled past it, and gone when the page's last card,
// whose button asks the same, comes up. Both are read against the window's
// bottom edge, where the bar sits.
export default class extends Controller {
  static targets = ["bar", "projects", "end"]

  connect() {
    this.read = this.read.bind(this)
    window.addEventListener("scroll", this.read, { passive: true })
    window.addEventListener("resize", this.read)
    this.read()
  }

  disconnect() {
    window.removeEventListener("scroll", this.read)
    window.removeEventListener("resize", this.read)
  }

  read() {
    const foot = window.innerHeight
    const shown = this.projectsTarget.getBoundingClientRect().bottom < foot && this.endTarget.getBoundingClientRect().top > foot
    this.barTarget.toggleAttribute("data-shown", shown)
    this.barTarget.inert = !shown
  }
}
