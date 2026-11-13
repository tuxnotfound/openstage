import { describe, expect, test } from "vitest"
import { onWidthChange } from "../../app/javascript/charts/filter/widthChange"

// A window as far as the listener reads it: its width, and its resize event.
function fakeWindow(innerWidth: number) {
  return Object.assign(new EventTarget(), { innerWidth }) as EventTarget & { innerWidth: number }
}

function resize(target: EventTarget & { innerWidth: number }, width: number) {
  target.innerWidth = width
  target.dispatchEvent(new Event("resize"))
}

describe("a chart's tooltip as the window resizes", () => {
  test("closes when the width changes, once per change", () => {
    const target = fakeWindow(1280)
    let closed = 0
    onWidthChange(target as unknown as Window, () => { closed += 1 })

    resize(target, 390)
    resize(target, 390)
    resize(target, 1024)

    expect(closed).toBe(2)
  })

  // A phone's address bar changes the height alone as the page scrolls.
  test("stays open when only the height changes", () => {
    const target = fakeWindow(390)
    let closed = 0
    onWidthChange(target as unknown as Window, () => { closed += 1 })

    target.dispatchEvent(new Event("resize"))

    expect(closed).toBe(0)
  })

  test("stops listening once its chart is gone", () => {
    const target = fakeWindow(1280)
    let closed = 0
    const stop = onWidthChange(target as unknown as Window, () => { closed += 1 })

    stop()
    resize(target, 390)

    expect(closed).toBe(0)
  })
})
