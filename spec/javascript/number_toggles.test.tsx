import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, test } from "vitest"
import NumberToggles from "../../app/javascript/charts/filter/NumberToggles"
import type { NumberView } from "../../app/javascript/charts/types"

const events = { toggle: () => {}, warm: () => {}, focus: () => {} }

describe("a toggle's bar", () => {
  test("splits its total in the projects' colours, and leaves the share of a project with none empty", () => {
    const commits: NumberView = {
      key: "commits", label: "Commits", word: "commits", group: "On GitHub", value: "12", change: null,
      split: [{ key: "me/app", colorClass: "os-project-1", value: 9 }, { key: "me/quiet", colorClass: null, value: 3 }],
    }
    const html = renderToStaticMarkup(<NumberToggles numbers={[commits]} lines={{ commits: 0 }} indexed={false} changes={false} {...events} />)
    // Each toggle draws twice: in the row, and in the ruler that measures it.
    const parts = [...html.matchAll(/<span class="min-w-\[3px\] rounded-\[2px\] ?([^"]*)" style="flex:([^"]*)"/g)].map(([, css = "", flex = ""]) => [css.trim(), flex.trim()])

    expect(parts).toEqual([["os-project-1 bg-(--project)", "9 1 0"], ["", "3 1 0"], ["os-project-1 bg-(--project)", "9 1 0"], ["", "3 1 0"]])
  })
})
