import { Controller } from "@hotwired/stimulus"

// The header's Dark / Light button. It flips the page and keeps the pick in a
// cookie for a year, so the server draws the next page the same way. Until the
// visitor picks, the page follows the system setting. The theme sits on
// <body> because a Turbo visit replaces the body but keeps <html> as it was.
export default class extends Controller {
  toggle() {
    const body = document.body
    const dark = body.dataset.theme ? body.dataset.theme === "dark" : matchMedia("(prefers-color-scheme: dark)").matches
    const theme = dark ? "light" : "dark"
    const secure = location.protocol === "https:" ? "; secure" : ""

    body.dataset.theme = theme
    document.cookie = `theme=${theme}; path=/; max-age=31536000; samesite=lax${secure}`
  }
}

// Turbo shows a page it kept from an earlier visit before the fresh one
// arrives, and a page kept before a switch carries the old theme, so every
// page Turbo is about to show takes the theme on screen. Controllers load
// eagerly, so this listens from the first page on.
addEventListener("turbo:before-render", ({ detail }) => {
  const theme = document.body.dataset.theme
  if (theme) detail.newBody.dataset.theme = theme
  else delete detail.newBody.dataset.theme
})
