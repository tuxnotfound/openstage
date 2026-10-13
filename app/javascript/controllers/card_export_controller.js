import { Controller } from "@hotwired/stimulus"

// Draws the card in the preview to a PNG, in the browser: the same SVG the
// server rendered, with its fonts and the avatar inlined so nothing outside
// the image is needed, at twice the size for sharp text.
export default class extends Controller {
  static targets = ["button"]
  static values = { fonts: Array, filename: String, trackUrl: String }

  async download() {
    const svg = document.querySelector("#card_preview svg[data-week-card]")
    if (!svg) return

    this.busy(true)
    try {
      const blob = await this.render(svg)
      const link = document.createElement("a")
      link.href = URL.createObjectURL(blob)
      link.download = this.filenameValue
      link.click()
      setTimeout(() => URL.revokeObjectURL(link.href), 2000)
      this.report("card_downloaded")
    } finally {
      this.busy(false)
    }
  }

  async render(svg) {
    const { width, height } = svg.viewBox.baseVal
    const clone = svg.cloneNode(true)
    clone.setAttribute("width", width)
    clone.setAttribute("height", height)

    const faces = await Promise.all(this.fontsValue.map(async (font) =>
      `@font-face{font-family:'${font.family}';font-style:${font.style};font-weight:${font.weight};src:url(${await this.dataUrl(font.url)}) format('woff2');}`))
    const style = document.createElementNS("http://www.w3.org/2000/svg", "style")
    style.textContent = faces.join("")
    clone.querySelector("defs").prepend(style)

    for (const image of clone.querySelectorAll("image")) {
      try {
        image.setAttribute("href", await this.dataUrl(image.getAttribute("href")))
      } catch {
        image.remove()
      }
    }

    const picture = new Image()
    picture.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(new XMLSerializer().serializeToString(clone))
    await picture.decode()

    const canvas = document.createElement("canvas")
    canvas.width = width * 2
    canvas.height = height * 2
    canvas.getContext("2d").drawImage(picture, 0, 0, canvas.width, canvas.height)
    return new Promise((resolve) => canvas.toBlob(resolve, "image/png"))
  }

  async dataUrl(url) {
    const response = await fetch(url)
    if (!response.ok) throw new Error(`${url}: ${response.status}`)

    const blob = await response.blob()
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = () => resolve(reader.result)
      reader.onerror = reject
      reader.readAsDataURL(blob)
    })
  }

  busy(on) {
    if (!this.hasButtonTarget) return

    this.buttonTarget.disabled = on
    this.buttonTarget.textContent = on ? "Drawing…" : "Download card"
  }

  report(name) {
    if (!this.trackUrlValue) return

    fetch(this.trackUrlValue, {
      method: "POST",
      keepalive: true,
      headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content },
      body: JSON.stringify({ name, detail: "" })
    }).catch(() => {})
  }
}
