// Calls close when the window's width changes. A tooltip keeps its place in
// pixels, so a desktop's tip left open as the window narrowed to a phone's
// width ran past the page's edge and scrolled it sideways until a reload.
// The height alone never closes it: a phone's address bar changes the height
// as the page scrolls, and a tapped tip stays. Returns what stops listening.
type Target = Pick<Window, "innerWidth" | "addEventListener" | "removeEventListener">

export function onWidthChange(target: Target, close: () => void): () => void {
  let width = target.innerWidth
  const listener = () => {
    if (target.innerWidth === width) return
    width = target.innerWidth
    close()
  }
  target.addEventListener("resize", listener)
  return () => target.removeEventListener("resize", listener)
}
