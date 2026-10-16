import { Controller } from "@hotwired/stimulus"

// Saves every change to the week card as the builder makes it, then redraws
// the preview from the server. The post box counts the builder's own text,
// which they copy out or carry to X; the card goes along as a download. Until
// the builder edits it, the post is the card's own draft and changes with the
// card.
export default class extends Controller {
  static targets = ["form", "post", "counter", "intent", "copyButton", "zone", "choice"]
  static values = { saveUrl: String, previewUrl: String, trackUrl: String, limit: { type: Number, default: 280 } }

  connect() {
    this.draft = this.currentDraft
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
    const response = await this.patch(body)
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

  // A post that is still the draft is saved empty, so the editor shows the
  // card's latest draft whenever it opens.
  async save(event) {
    event?.preventDefault()
    clearTimeout(this.timer)
    const body = new FormData(this.formTarget)
    if (this.following) body.set("week_card[post_text]", "")
    const response = await this.patch(body)
    if (!response.ok) return

    // The frame keeps the old card on screen until the new one arrives.
    document.getElementById("card_preview").src = `${this.previewUrlValue}?v=${Date.now()}`
  }

  // Each redrawn card brings its draft; an unedited post takes it.
  follow() {
    const draft = this.currentDraft
    if (draft === undefined) return

    if (this.following) {
      this.postTarget.value = draft
      this.count()
    }
    this.draft = draft
  }

  get following() {
    return this.hasPostTarget && this.draft !== undefined && this.plain(this.postTarget.value) === this.plain(this.draft)
  }

  get currentDraft() {
    return document.querySelector("#card_preview [data-card-draft]")?.dataset.cardDraft
  }

  plain(text) {
    return text.replace(/\r\n/g, "\n").trim()
  }

  patch(body) {
    return fetch(this.saveUrlValue, {
      method: "PATCH",
      body,
      headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
    })
  }

  count() {
    if (!this.hasPostTarget) return

    const text = this.postTarget.value
    const length = [...text].length
    this.counterTarget.textContent = `${length} / ${this.limitValue}`
    this.counterTarget.classList.toggle("text-red-600", length > this.limitValue)
    this.intentTargets.forEach((link) => { link.href = link.dataset.base + encodeURIComponent(text) })
  }

  useDraft() {
    const draft = this.currentDraft
    if (!draft) return

    this.draft = draft
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

  // The compose link opens a new tab, so the report must not block the click.
  intent(event) {
    this.report("recap_intent", event.currentTarget.dataset.network)
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
