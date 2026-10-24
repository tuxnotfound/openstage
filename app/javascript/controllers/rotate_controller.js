import { Controller } from "@hotwired/stimulus"

// Shows its items one at a time, the first as the server drew it and the rest
// in a random order, the next fading in every few seconds. It holds while the
// pointer or focus is on it. With reduced motion, or a single item, it shows
// one and stays.
export default class extends Controller {
  static targets = ["item"]
  static values = { interval: { type: Number, default: 4500 } }

  connect() {
    this.order = [0, ...shuffled(this.itemTargets.length).filter((i) => i !== 0)]
    this.at = 0
    this.held = false
    this.stopped = matchMedia("(prefers-reduced-motion: reduce)").matches || this.itemTargets.length < 2
    this.timer = setInterval(() => this.next(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  next() {
    if (this.stopped || this.held) return
    this.at = (this.at + 1) % this.order.length
    const shown = this.order[this.at]
    this.itemTargets.forEach((item, i) => {
      item.classList.toggle("opacity-0", i !== shown)
      item.inert = i !== shown
    })
  }

  hold() {
    this.held = true
  }

  release() {
    this.held = false
  }
}

// 0 to n - 1 in a random order.
function shuffled(n) {
  const order = Array.from({ length: n }, (_, i) => i)
  for (let i = n - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[order[i], order[j]] = [order[j], order[i]]
  }
  return order
}
