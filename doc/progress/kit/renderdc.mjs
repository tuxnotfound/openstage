// Static render of a canvas artboard (.dc.html) for screenshots: runs its
// renderVals with the given props and state, expands sc-for and sc-if, fills
// {{paths}}, swaps the uploaded avatar for the local file and a <dc-import>
// for a labelled box. Events and dc-import are not run.
// Usage: node renderdc.mjs <file.dc.html> <out.html> '<{"props":{},"state":{}}>' [width]
import { readFileSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const [file, out, json, widthArg] = process.argv.slice(2)
const cfg = JSON.parse(json || "{}")
const src = readFileSync(file, "utf8")

const xdc = src.match(/<x-dc>([\s\S]*?)<\/x-dc>/)[1]
const helmet = (xdc.match(/<helmet>([\s\S]*?)<\/helmet>/) || [, ""])[1]
const body = xdc.replace(/<helmet>[\s\S]*?<\/helmet>/, "")
const script = src.match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/)[1]
class DCLogic { constructor(p) { this.props = p || {}; this.state = this.state || {} } setState() {} forceUpdate() {} }
const Component = new Function("DCLogic", `${script}; return Component`)(DCLogic)
const c = new Component(cfg.props || {})
if (cfg.state) c.state = Object.assign({}, c.state, cfg.state)
const vals = c.renderVals()

const resolve = (path, scope) => path.trim().split(".").reduce((v, k) => (v == null ? v : v[k]), scope)
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
      list.forEach((item, idx) => { outStr += expand(inner, { ...scope, [attr("as")]: item, $index: idx }) })
    } else if (resolve(attr("value"), scope)) {
      outStr += expand(inner, scope)
    }
    i = after
    re.lastIndex = after
  }
  return outStr + fill(str.slice(i), scope)
}
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
const fill = (s, scope) => s
  .replace(/\s(on[A-Z][A-Za-z]*)="\{\{[^}]*\}\}"/g, "")
  .replace(/\s(disabled|selected|checked)="\{\{([^}]*)\}\}"/g, (_, a, p) => (resolve(p, scope) ? ` ${a}` : ""))
  .replace(/\{\{([^}]*)\}\}/g, (_, p) => { const v = resolve(p, scope); return v == null ? "" : typeof v === "function" ? "" : esc(v) })

const avatar = pathToFileURL(join(here, "avatar.jpg")).href
const width = Number(widthArg || 1280)
const html = `<!doctype html><html><head><meta charset="utf-8">${helmet}
<style>html,body{margin:0;padding:0}</style></head><body style="width:${width}px">${expand(body, vals)
  .replaceAll("/_blob/59b36a5d4069a14bd0e0e68e44a14127", avatar)
  .replace(/<dc-import\b[^>]*><\/dc-import>/g, '<div style="width:1200px;height:630px;background:#E5E7EB;display:flex;align-items:center;justify-content:center;color:#6B7280;font:32px sans-serif">card preview (rendered separately)</div>')}</body></html>`
writeFileSync(out, html)
console.log(out)
