import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sentinel", "link"]

  connect() {
    this.loading = false
    this.hasScrolled = false
    this.canTrigger = true
    this.isIntersecting = false
    if (!this.hasSentinelTarget || !this.hasLinkTarget) return

    this.handleScroll = this.handleScroll.bind(this)
    window.addEventListener("scroll", this.handleScroll, { passive: true })

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          this.isIntersecting = entry.isIntersecting
          if (!entry.isIntersecting) {
            this.canTrigger = true
            return
          }

          if (this.hasScrolled && this.canTrigger) {
            this.canTrigger = false
            this.loadMore()
          }
        })
      },
      { rootMargin: "220px 0px" }
    )

    this.observer.observe(this.sentinelTarget)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    window.removeEventListener("scroll", this.handleScroll)
  }

  handleScroll() {
    if (window.scrollY > 80) this.hasScrolled = true

    if (this.hasScrolled && this.isIntersecting && this.canTrigger) {
      this.canTrigger = false
      this.loadMore()
    }
  }

  loadMore() {
    if (this.loading) return
    this.loading = true
    this.linkTarget.click()
  }
}
