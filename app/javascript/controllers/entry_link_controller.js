import { Controller } from "@hotwired/stimulus"

// A link to an entry ends in #entry-<id>. Links shared before ?entry= existed
// carry only that, and the page as drawn may not show the entry (an older
// commit, or one outside the window). Then the page asks for it again with
// ?entry=<id>, which shows it at the top, and the anchor lands there.
export default class extends Controller {
  connect() {
    const id = location.hash.match(/^#entry-(\d+)$/)?.[1]
    if (!id || document.getElementById(`entry-${id}`)) return

    const url = new URL(location.href)
    if (url.searchParams.get("entry") === id) return

    url.searchParams.set("entry", id)
    window.Turbo.visit(url.toString(), { action: "replace" })
  }
}
