import { Controller } from "@hotwired/stimulus"

// Counts this page's view from the browser, with the ticket the server put in
// it, so a client that only fetches the page counts none. Once per ticket: a
// page Turbo shows again from its cache, as a preview or on Back, carries the
// ticket it already sent.
const sent = new Set()

export default class extends Controller {
  static values = { ticket: String, url: String }

  connect() {
    const ticket = this.ticketValue
    if (!ticket || sent.has(ticket) || navigator.webdriver) return
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    sent.add(ticket)
    const body = new URLSearchParams({ t: ticket })
    if (navigator.sendBeacon && navigator.sendBeacon(this.urlValue, body)) return
    // A view that fails to send is one view uncounted; the console need not hear of it.
    fetch(this.urlValue, { method: "POST", body: body, keepalive: true }).catch(() => {})
  }
}
