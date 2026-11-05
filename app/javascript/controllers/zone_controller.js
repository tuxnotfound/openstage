import { Controller } from "@hotwired/stimulus"

// Tells Openstage the builder's time zone. The layout renders this only while
// they have none, so it runs once, and a trip abroad never moves their days.
export default class extends Controller {
  static values = { url: String }

  connect() {
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({ time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone })
    })
  }
}
