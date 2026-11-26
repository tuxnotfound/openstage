import { Controller } from "@hotwired/stimulus"

// The dashboard's entry box: one line until the builder is in it; then it
// grows to the kinds and every field, as a project's numbers come in on
// Projects, with the same 0.42 s and curve. The line makes room, the
// fields beside it follow its edge in from the right, and the rest slides
// its last 28 px down. A click outside the box, or Escape, folds it back to
// its line. The fields only hide, so what was typed in them stays.
const TIME = 420
const EASE = "cubic-bezier(.33, 1, .68, 1)"
const SLIDE = "translateY(-28px)"
const PARTS = ".dt-kinds, .dt-area, .dt-url, .dt-repo, .dt-when, .dt-send"
const BESIDE = ".dt-url, .dt-repo, .dt-when"

export default class extends Controller {
  static targets = ["form", "line"]

  connect() {
    this.opened = this.formTarget.classList.contains("open")
    this.running = []
    this.outside = (event) => { if (!this.element.contains(event.target)) this.close() }
    document.addEventListener("pointerdown", this.outside)
  }

  disconnect() {
    document.removeEventListener("pointerdown", this.outside)
    this.stop()
  }

  open() {
    if (this.opened || this.quiet) return
    this.opened = true
    const from = this.measure()
    const now = this.partsNow()
    this.stop()
    this.formTarget.classList.add("open")
    if (this.still()) return
    const open = this.measure()
    const room = from.width - open.width
    const parts = now ?? this.parts().map((part) => [part, 0, this.away(part, room)])
    this.play(from, open, open, parts, () => [1, "none"]).catch(() => {})
  }

  close() {
    if (!this.opened) return
    this.opened = false
    const from = this.measure()
    const now = this.partsNow()
    this.stop()
    const form = this.formTarget
    form.classList.remove("open")
    const shut = this.measure()
    if (this.still()) return
    form.classList.add("open")
    const open = this.measure()
    const room = shut.width - open.width
    const parts = now ?? this.parts().map((part) => [part, 1, "none"])
    this.play(from, shut, open, parts, (part) => [0, this.away(part, room)]).then(() => {
      form.classList.remove("open")
      this.stop()
      form.querySelector(":scope > .dt-shut")?.animate({ opacity: [0, 1] }, { duration: 160, easing: "ease" })
    }, () => {})
  }

  // Escape folds the box; the focus stays on its line, which stays.
  escape() {
    if (!this.opened) return
    if (this.formTarget.contains(document.activeElement) && document.activeElement !== this.lineTarget) {
      this.quiet = true
      this.lineTarget.focus()
      this.quiet = false
    }
    this.close()
  }

  // The box's height, and where its line stands in it, as painted now.
  measure() {
    const box = this.formTarget.getBoundingClientRect()
    const line = this.lineTarget.getBoundingClientRect()
    return { height: box.height, top: line.top - box.top, left: line.left - box.left, width: line.width }
  }

  parts() {
    return [...this.formTarget.querySelectorAll(PARTS)]
  }

  // Each part's opacity and transform as painted now, when a growth or a
  // fold is cut short; nil when nothing moves.
  partsNow() {
    if (!this.running.length) return null
    return this.parts().map((part) => {
      const style = getComputedStyle(part)
      return [part, Number(style.opacity), style.transform]
    })
  }

  // Where a part waits while the box is folded. Beside the line, it stands
  // past the line's right edge by the room the line makes (room); the rest,
  // and every part in one column, 28 px up.
  away(part, room) {
    return room > 0 && part.matches(BESIDE) ? `translateX(${room}px)` : SLIDE
  }

  // From one state to another over the open layout (base): the box's
  // height, its line's place and width, and each part's fade and slide to
  // where end(part) says.
  play(from, to, base, parts, end) {
    const form = this.formTarget
    const timing = { duration: TIME, easing: EASE, fill: "both" }
    const at = (state) => `translate(${state.left - base.left}px, ${state.top - base.top}px)`
    form.style.overflow = "clip"
    form.style.overflowClipMargin = "4px"
    this.running = [
      form.animate({ height: [`${from.height}px`, `${to.height}px`] }, timing),
      this.lineTarget.animate({ transform: [at(from), at(to)], width: [`${from.width}px`, `${to.width}px`] }, timing),
      ...parts.flatMap(([part, opacity, transform]) => {
        const [endOpacity, endTransform] = end(part)
        return [
          part.animate({ opacity: [opacity, endOpacity] }, { duration: 260, delay: 30, easing: "ease", fill: "both" }),
          part.animate({ transform: [transform, endTransform] }, timing),
        ]
      }),
    ]
    return Promise.all(this.running.map((animation) => animation.finished)).then(() => {
      if (this.opened) this.stop()
    })
  }

  stop() {
    this.running.forEach((animation) => animation.cancel())
    this.running = []
    this.formTarget.style.overflow = ""
    this.formTarget.style.overflowClipMargin = ""
  }

  still() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
