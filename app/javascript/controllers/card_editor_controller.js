import { Controller } from "@hotwired/stimulus"

// Saves every change to the week card as the builder makes it, then redraws
// the preview from the server. The post box counts the builder's own text,
// which they copy out with the downloaded card.
export default class extends Controller {
  static targets = ["form", "post", "counter", "copyButton", "zone", "choice"]
  static values = { saveUrl: String, previewUrl: String, trackUrl: String, limit: { type: Number, default: 280 } }

  connect() {
    this.count()
    this.adoptZone()
  }

  // The card counts days in the builder's own time zone. The first time the
  // browser's zone differs from the card's, save it alone and redraw the
  // editor, so the days and their suggestions move with it.
  async adoptZone() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!this.hasZoneTarget || !zone || this.zoneTarget.value === zone) return

    this.zoneTarget.value = zone
    const body = new FormData()
    body.append("week_card[time_zone]", zone)
    const response = await fetch(this.saveUrlValue, {
      method: "PATCH",
      body,
      headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
    })
    if (!response.ok) return

    const saved = await response.json()
    if (saved.time_zone === zone) window.Turbo?.visit(window.location.href, { action: "replace" })
  }

  // Offers only what the chosen template draws. A hidden choice keeps its
  // value, so switching back finds it as the builder left it.
  filter() {
    const chosen = this.formTarget.querySelector("input[name='week_card[style]']:checked")?.value
    this.choiceTargets.forEach((choice) => { choice.hidden = !choice.dataset.templates.split(" ").includes(chosen) })
  }

  queue() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.save(), 500)
  }

  async save(event) {
    event?.preventDefault()
    clearTimeout(this.timer)
    const response = await fetch(this.saveUrlValue, {
      method: "PATCH",
      body: new FormData(this.formTarget),
      headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
    })
    if (!response.ok) return

    // The frame keeps the old card on screen until the new one arrives.
    document.getElementById("card_preview").src = `${this.previewUrlValue}?v=${Date.now()}`
  }

  count() {
    if (!this.hasPostTarget) return

    const text = this.postTarget.value
    const length = [...text].length
    this.counterTarget.textContent = `${length} / ${this.limitValue}`
    this.counterTarget.classList.toggle("text-red-600", length > this.limitValue)
  }

  useDraft() {
    const draft = document.querySelector("#card_preview [data-card-draft]")?.dataset.cardDraft
    if (!draft) return

    this.postTarget.value = draft
    this.count()
    this.queue()
  }

  copy() {
    this.report("recap_copied")
    navigator.clipboard.writeText(this.postTarget.value)
      .then(() => this.flash("Copied"))
      .catch(() => this.flash("Press Cmd+C"))
  }

  report(name, detail = "") {
    if (!this.trackUrlValue) return

    fetch(this.trackUrlValue, {
      method: "POST",
      keepalive: true,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": this.csrfToken },
      body: JSON.stringify({ name, detail })
    }).catch(() => {})
  }

  flash(message) {
    const button = this.copyButtonTarget
    const original = button.textContent
    button.textContent = message
    setTimeout(() => { button.textContent = original }, 1500)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
