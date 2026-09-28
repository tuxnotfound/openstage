import { Controller } from "@hotwired/stimulus"

// Share a public page. Native share sheet where there is one, copy the link
// elsewhere. Never shows a count of anything.
export default class extends Controller {
  static values = { url: String, title: String }
  static targets = ["button"]

  share() {
    if (navigator.share) {
      navigator.share({ title: this.titleValue, url: this.urlValue }).catch(() => {})
      return
    }
    navigator.clipboard.writeText(this.urlValue)
      .then(() => this.flash("Link copied"))
      .catch(() => this.flash("Press Cmd+C"))
  }

  flash(message) {
    const button = this.buttonTarget
    const original = button.textContent
    button.textContent = message
    setTimeout(() => { button.textContent = original }, 1500)
  }
}
