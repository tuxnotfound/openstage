// Turns a design-canvas mock (doc/week_cards/mocks/*.dc.html) into a static HTML page:
// runs the mock's renderVals with the given props, expands sc-for and sc-if, and fills
// {{paths}}. shot.sh then screenshots the page. Only this subset of the canvas format
// is supported, which is all the mocks use.
// Usage: node render.mjs <mock.dc.html> <out.html> '<props json>'
import { readFileSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const [file, out, propsJson] = process.argv.slice(2)
const src = readFileSync(file, "utf8")
const props = JSON.parse(propsJson || "{}")

const xdc = src.match(/<x-dc>([\s\S]*?)<\/x-dc>/)[1]
const helmet = (xdc.match(/<helmet>([\s\S]*?)<\/helmet>/) || [, ""])[1]
const body = xdc.replace(/<helmet>[\s\S]*?<\/helmet>/, "")
const script = src.match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/)[1]
class DCLogic { constructor(p) { this.props = p } }
const Component = new Function("DCLogic", `${script}; return Component`)(DCLogic)
const vals = new Component(props).renderVals()

const resolve = (path, scope) => path.trim().split(".").reduce((v, k) => (v == null ? v : v[k]), scope)

// The matching close tag for an sc-for or sc-if, counting nesting.
function block(str, start, tag) {
  const re = new RegExp(`<${tag}\\b[^>]*>|</${tag}>`, "g")
  re.lastIndex = start
  let depth = 0, m
  while ((m = re.exec(str))) {
    depth += m[0].startsWith("</") ? -1 : 1
    if (depth === 0) return { end: m.index, after: re.lastIndex }
  }
  throw new Error(`unclosed ${tag}`)
}

function expand(str, scope) {
  let outStr = "", i = 0
  const re = /<(sc-for|sc-if)\b([^>]*)>/g
  let m
  while ((m = re.exec(str))) {
    if (m.index < i) continue
    outStr += fill(str.slice(i, m.index), scope)
    const tag = m[1]
    const { end, after } = block(str, m.index, tag)
    const inner = str.slice(m.index + m[0].length, end)
    const attr = (name) => (m[2].match(new RegExp(`${name}="\\{\\{([^}]*)\\}\\}"`)) || m[2].match(new RegExp(`${name}="([^"]*)"`)) || [])[1]
    if (tag === "sc-for") {
      const list = resolve(attr("list"), scope) || []
      for (const item of list) outStr += expand(inner, { ...scope, [attr("as")]: item })
    } else if (resolve(attr("value"), scope)) {
      outStr += expand(inner, scope)
    }
    i = after
    re.lastIndex = after
  }
  return outStr + fill(str.slice(i), scope)
}

const fill = (s, scope) => s.replace(/\{\{([^}]*)\}\}/g, (_, p) => { const v = resolve(p, scope); return v == null ? "" : String(v) })

// The mocks load their fonts from Google Fonts (in the helmet). DM Sans and DM Mono are
// also declared from the app's own files, as the app draws with those.
const fonts = pathToFileURL(join(here, "..", "..", "..", "app", "assets", "fonts")).href
const avatar = pathToFileURL(join(here, "..", "assets", "avatar.jpg")).href
const html = `<!doctype html><html><head><meta charset="utf-8">${helmet}
<style>@font-face{font-family:'DM Sans';font-weight:100 1000;src:url('${fonts}/dm-sans.woff2') format('woff2')}
@font-face{font-family:'DM Mono';font-weight:400;src:url('${fonts}/dm-mono-400.woff2') format('woff2')}
@font-face{font-family:'DM Mono';font-weight:500;src:url('${fonts}/dm-mono-500.woff2') format('woff2')}
html,body{margin:0;padding:0;overflow:hidden}</style></head><body>${expand(body, vals).replaceAll("/_blob/1e393e927f6a7146a6c82436c6086f9c", avatar)}</body></html>`
writeFileSync(out, html)
