import { createRoot, type Root } from "react-dom/client"
import { flushSync } from "react-dom"
import ProgressIsland, { type ProgressProps } from "./progress/ProgressIsland"
import AnalyticsIsland, { type AnalyticsProps } from "./analytics/AnalyticsIsland"

// Mounts each [data-react] island over the HTML the server rendered for it,
// with the props in the <script type="application/json"> it names. The server
// HTML is kept and put back before Turbo caches the page, so a cached
// snapshot and a page without JavaScript look the same.

type Mounted = { root: Root; element: HTMLElement; restores: [HTMLElement, string][] }

const mounted: Mounted[] = []

function render(name: string, props: unknown) {
  if (name === "progress") return <ProgressIsland {...(props as ProgressProps)} />
  if (name === "analytics") return <AnalyticsIsland {...(props as AnalyticsProps)} />
  return null
}

function mount() {
  unmount((island) => !island.element.isConnected)
  document.querySelectorAll<HTMLElement>("[data-react]").forEach((element) => {
    if (element.dataset.reactMounted) return
    const source = element.dataset.reactProps ? document.getElementById(element.dataset.reactProps) : null
    if (!source?.textContent) return

    const props = JSON.parse(source.textContent) as { shippedTarget?: string }
    const targets = [element, props.shippedTarget && document.getElementById(props.shippedTarget)].filter((each): each is HTMLElement => !!each)
    const restores = targets.map((target): [HTMLElement, string] => [target, target.innerHTML])
    targets.forEach((target) => target.replaceChildren())
    element.dataset.reactMounted = "true"
    const root = createRoot(element)
    flushSync(() => root.render(render(element.dataset.react ?? "", props)))
    mounted.push({ root, element, restores })
  })
}

function unmount(which: (island: Mounted) => boolean = () => true) {
  for (let i = mounted.length - 1; i >= 0; i--) {
    const island = mounted[i]
    if (!island || !which(island)) continue
    island.root.unmount()
    island.restores.forEach(([target, html]) => { target.innerHTML = html })
    delete island.element.dataset.reactMounted
    mounted.splice(i, 1)
  }
}

document.addEventListener("turbo:load", mount)
document.addEventListener("turbo:frame-load", mount)
document.addEventListener("turbo:before-cache", () => unmount())
if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mount)
else mount()
