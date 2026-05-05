import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sentinel", "link"]

  connect() {
    this.loading = false
    if (!this.hasSentinelTarget || !this.hasLinkTarget) return

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) this.loadMore()
        })
      },
      { rootMargin: "220px 0px" }
    )

    this.observer.observe(this.sentinelTarget)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }

  loadMore() {
    if (this.loading) return
    this.loading = true
    this.linkTarget.click()
  }
}
