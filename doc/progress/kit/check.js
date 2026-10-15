// Runs an artboard's renderVals across many props and states and reports
// exceptions and suspicious output (NaN, undefined, Infinity in any string).
// Usage: node kit/check.js <file.dc.html> page|card
const fs = require('fs');
const [file, kind] = process.argv.slice(2);
const src = fs.readFileSync(file, 'utf8');
const script = src.match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/)[1];
class DCLogic { constructor(p) { this.props = p || {}; } setState(s) { this.state = Object.assign({}, this.state, typeof s === 'function' ? s(this.state) : s); } forceUpdate() {} }
const Component = new Function('DCLogic', script + '; return Component')(DCLogic);
let runs = 0, bad = 0;
const scan = (v, path, label) => {
  if (typeof v === 'string') { if (/NaN|undefined|Infinity/.test(v)) { bad++; if (bad < 25) console.log('SUSPICIOUS', label, path, JSON.stringify(v.slice(0, 120))); } }
  else if (typeof v === 'number') { if (!isFinite(v)) { bad++; if (bad < 25) console.log('NONFINITE', label, path, v); } }
  else if (Array.isArray(v)) v.forEach((x, i) => scan(x, path + '.' + i, label));
  else if (v && typeof v === 'object') Object.keys(v).forEach(k => scan(v[k], path + '.' + k, label));
};
const run = (props, state, label) => {
  runs++;
  try { const c = new Component(props); if (state) c.state = Object.assign({}, c.state, state); scan(c.renderVals(), '', label); }
  catch (e) { bad++; console.log('ERROR', label, e && e.stack ? e.stack.split('\n').slice(0, 3).join(' | ') : e); }
};
const ranges = [['week', 0], ['week', -1], ['week', -3], ['month', 0], ['month', -1], ['month', -2], ['month', -7], ['year', 0], ['year', -1], ['all', 0]];
const projects = [null, 0, 1, 2, 3, 4, 5, 6];
const sample = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0, 10: 3, 11: 0, 12: 2, 13: 0, 14: 0, 15: -1, 16: 0, 17: -1, 19: -1, 20: -1 };
if (kind === 'card') {
  for (const [range, offset] of ranges) for (const theme of ['light', 'dark']) for (const project of projects) for (const tags of [{}, sample]) {
    run({ range, offset, theme, project: project == null ? '' : String(project), tags: JSON.stringify(tags), feature: '' }, null, `${range}${offset} ${theme} p=${project} tags=${Object.keys(tags).length}`);
  }
  run({ range: 'year', offset: 0, theme: 'light', project: '', tags: '{}', feature: '8,2' }, null, 'feature 8,2');
  run({}, null, 'no props');
} else {
  for (const viewer of ['owner', 'visitor']) for (const [range, offset] of ranges) for (const project of projects) for (const tags of [{}, sample]) for (const hover of [null, 0, 3]) {
    run({ viewer }, { range, offset, project, tags, hover, modal: true, tagOpen: true, tagMore: hover === 3, feature: hover === 3 ? [8] : [] }, `${viewer} ${range}${offset} p=${project} tags=${Object.keys(tags).length} hover=${hover}`);
  }
  run({}, null, 'defaults');
}
console.log(`${runs} runs, ${bad} problems`);
process.exit(bad ? 1 : 0);
