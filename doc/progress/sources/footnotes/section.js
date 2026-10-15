// Footnotes: numbered discs ride the bars and the same numbers start each note
// in the list below, so chart and words read in one time order. The plot
// carries no text.
const OPTION = { key: 'footnotes', cap: () => 6, cardCap: () => 6, glyphs: 'disc' };

// Chart geometry in viewBox units, which equal px at a 704px column. The top
// tick never moves: discs live in the fixed headroom above it.
const FN = { W: 704, H: 220, L: 30, R: 698, T: 34, B: 196, disc: 16, pill: 26, lift: 3, gap: 2 };
const FLASH = '#FEF3C7';

// Below a 600px column the discs shrink to dots and lose their numerals. The
// chart box is a size container, so this step function reads its own width.
function fnStep(lo, hi) { return 'clamp(' + lo + 'px, calc((100cqw - 599px) * 1000), ' + hi + 'px)'; }

// ----- Chart helpers. This block is identical in section.js and card.src.dc.html
// (the assembler pastes only core.js into the card), so edit both together.

function niceTicks(max) {
  const raw = max / 3; const p = Math.pow(10, Math.floor(Math.log10(raw))); const m = raw / p;
  const step = (m <= 1 ? 1 : m <= 2 ? 2 : m <= 2.5 ? 2.5 : m <= 5 ? 5 : 10) * p;
  const top = Math.ceil(max / step - 1e-9) * step; const out = [];
  for (let v = 0; v <= top + 1e-9; v += step) out.push(Math.round(v * 10) / 10);
  return out;
}
function box(x, y, w, h) { return 'M' + r1(x) + ',' + r1(y) + 'h' + r1(w) + 'v' + r1(h) + 'h' + r1(-w) + 'Z'; }
function roundTop(x, y, w, h, r) {
  r = Math.max(0, Math.min(r, h, w / 2));
  return 'M' + r1(x) + ',' + r1(y + h) + 'V' + r1(y + r) + 'Q' + r1(x) + ',' + r1(y) + ' ' + r1(x + r) + ',' + r1(y) + 'H' + r1(x + w - r) + 'Q' + r1(x + w) + ',' + r1(y) + ' ' + r1(x + w) + ',' + r1(y + r) + 'V' + r1(y + h) + 'Z';
}

// Stacked bars, one path per project; a 2px gap is carved off the top of
// every segment under another one. cols[i] holds a bar's centre and top.
function barsOf(bs, g, surface) {
  const slot = (g.R - g.L) / bs.length; const bw = Math.max(3, Math.min(24, slot * 0.62));
  const ticks = niceTicks(Math.max(4, ...bs.map(b => b.total))); const top = ticks[ticks.length - 1];
  const y = v => g.B - (v / top) * (g.B - g.T);
  const paths = DATA.projects.map(() => '');
  const cols = bs.map((b, i) => {
    const cx = g.L + slot * (i + 0.5); const x = cx - bw / 2;
    const segs = b.counts.map((v, pi) => [pi, v]).filter(s => s[1] > 0); let acc = 0;
    segs.forEach(([pi, v], k) => {
      const yb = y(acc), yt = y(acc + v); acc += v; const last = k === segs.length - 1;
      const yTop = last ? yt : Math.min(yt + 2, yb - 1);
      paths[pi] += last ? roundTop(x, yTop, bw, yb - yTop, 4) : box(x, yTop, bw, yb - yTop);
    });
    return { cx, x, top: y(b.total) };
  });
  return { slot, bw, cols, grid: ticks.slice(1).map(v => ({ v, y: r1(y(v)) })), fills: paths.map((d, pi) => ({ d, fill: colorOf(pi, surface) })) };
}

// The highest bar a disc standing at x would touch, with 1px to spare.
function reachTop(x, w, bars) {
  let top = Infinity;
  bars.cols.forEach(c => { if (c.x < x + w / 2 + 1 && c.x + bars.bw > x - w / 2 - 1) top = Math.min(top, c.top); });
  return top;
}

// Where each disc stands. A disc sits just above its own bar; other discs and
// taller neighbouring bars push it sideways. Every spot within two pills of the
// bar's centre is weighed by the distance moved (squared) plus 4 for each unit a
// taller bar would still lift the disc. The cheapest row of spots that keeps
// every pair of discs `gap` apart wins, so a disc moves only as far as it must
// and floats above its bar only when no spot beside it is clear.
function place(ds, bars, g) {
  const STEP = 0.5, LIFT = 4, N = Math.round(2 * g.pill / STEP);
  ds.forEach(d => { d.x = bars.cols[d.i].cx; });
  if (!ds.length) return;
  const spots = ds.map(d => {
    const own = bars.cols[d.i]; const row = [];
    for (let q = -N; q <= N; q++) {
      const x = own.cx + q * STEP;
      if (x - d.w / 2 >= g.L && x + d.w / 2 <= g.R) row.push({ x, cost: (q * STEP) * (q * STEP) + LIFT * Math.max(0, own.top - reachTop(x, d.w, bars)) });
    }
    return row;
  });
  // best[k][j]: the cheapest way to stand discs 0..k with disc k on its j-th spot.
  const best = [], from = [];
  spots.forEach((row, k) => {
    best.push([]); from.push([]);
    const apart = (ds[k - 1] ? (ds[k - 1].w + ds[k].w) / 2 : 0) + g.gap;
    let p = 0, low = Infinity, at = -1;
    row.forEach((s, j) => {
      if (k === 0) { best[k].push(s.cost); from[k].push(-1); return; }
      while (p < spots[k - 1].length && spots[k - 1][p].x <= s.x - apart + 1e-9) { if (best[k - 1][p] < low) { low = best[k - 1][p]; at = p; } p++; }
      best[k].push(at < 0 ? Infinity : low + s.cost); from[k].push(at);
    });
  });
  const end = best[ds.length - 1]; let j = end.indexOf(Math.min(...end));
  if (j < 0 || end[j] === Infinity) return;
  for (let k = ds.length - 1; k >= 0; k--) { ds[k].x = spots[k][j].x; j = from[k][j]; }
}

// One disc per bucket that holds notes, numbered in the notes' date order;
// several notes in one bucket share a pill such as "2–3".
function discsOf(bs, notes, bars, g) {
  const ds = [];
  notes.forEach((x, k) => {
    const t = ms(x.d); const i = bs.findIndex(b => t >= b.s && t <= b.e); if (i < 0) return;
    let d = ds.find(o => o.i === i);
    if (!d) { d = { i, notes: [] }; ds.push(d); }
    d.notes.push({ n: k + 1, x });
  });
  ds.sort((a, b) => a.i - b.i).forEach(d => {
    d.first = d.notes[0].n; d.last = d.notes[d.notes.length - 1].n;
    d.label = d.notes.length > 1 ? d.first + '–' + d.last : String(d.first);
    d.w = d.notes.length > 1 ? g.pill : g.disc;
    d.ship = d.notes.some(o => o.x.k === 's');
  });
  place(ds, bars, g);
  ds.forEach(d => { d.cy = reachTop(d.x, d.w, bars) - g.lift - g.disc / 2; });
  return ds;
}

// Year labels name months, so the month holding today is the current one.
function toneOf(p, bs, i) {
  const b = bs[i];
  if (p.range !== 'year') return b.today ? 'now' : b.future ? 'future' : 'past';
  const q = parts(b.mon + 3 * DAY); const s = Date.UTC(q.y, q.m, 1); const e = Date.UTC(q.y, q.m + 1, 1) - DAY;
  return s <= T0 && T0 <= e ? 'now' : s > T0 ? 'future' : 'past';
}

// ----- end of chart helpers -----

const byDate = (a, b) => (a.d < b.d ? -1 : a.d > b.d ? 1 : a.id - b.id);

// "in October 2026", "in 2026", "this week", "since March 2026".
function phraseOf(p, names) {
  if (p.range === 'month') return 'in ' + names.title;
  if (p.range === 'all') return names.sub.replace('Since', 'since');
  return names.word;
}

// The page shows the run-in capped at 160 characters on a word boundary.
function capRunIn(s, n) {
  const chars = Array.from(s);
  if (chars.length <= n) return s;
  const cut = chars.slice(0, n + 1).join(''); const sp = cut.lastIndexOf(' ');
  return (sp > 0 ? cut.slice(0, sp) : chars.slice(0, n).join('')).replace(/[\s,;:·–—-]+$/, '') + '…';
}

// The words of a list row, shared by the notes and the rest.
function rowTextOf(x, proj, filterTo) {
  const run = capRunIn(runInOf(x), 160);
  const tagged = proj == null && x.r != null;
  return {
    title: x.t, run, hasRun: run !== '', href: '#entry-' + x.id, date: fmtDay(ms(x.d)), pin: !!x.pin,
    chip: tagged, chipName: tagged ? DATA.projects[x.r] : '', chipColor: tagged ? colorOf(x.r, 'page') : PAGE.faint,
    chipPick: tagged ? filterTo(x.r) : null, chipHint: tagged ? 'Show only ' + DATA.projects[x.r] : ''
  };
}

function discLabelOf(d) {
  return d.notes.map(o => 'Note ' + o.n + ', ' + (o.x.k === 's' ? 'shipped ' : 'published ') + fmtDay(ms(o.x.d)) + ': ' + o.x.t).join('. ');
}

// The bar tooltip. Its entries lead with their disc (noted ones first, the lit
// ones in bold); entries without a note get a dot.
function tooltipOf(p, hb, bars, ds, litNotes) {
  const noteOf = {}; ds.forEach(d => d.notes.forEach(o => { noteOf[o.x.id] = o.n; }));
  const rows = hb.counts.map((n, pi) => ({ n, pi })).filter(r => r.n > 0).sort((a, b) => b.n - a.n)
    .map(r => ({ name: DATA.projects[r.pi], n: r.n, color: colorOf(r.pi, 'page') }));
  const all = hb.hl.slice().sort(byDate);
  const items = all.filter(x => noteOf[x.id] != null).concat(all.filter(x => noteOf[x.id] == null));
  const entries = items.slice(0, 4).map(x => {
    const n = noteOf[x.id]; const noted = n != null; const bold = noted && litNotes.indexOf(n) >= 0;
    return {
      t: x.t, mark: noted ? String(n) : '·', fw: bold ? '600' : '400', color: bold ? '#ffffff' : '#E5E7EB',
      bg: noted && x.k === 's' ? '#F9FAFB' : 'transparent', fg: noted ? (x.k === 's' ? PAGE.ink : '#F9FAFB') : '#9CA3AF',
      border: noted && x.k !== 's' ? '1.5px solid #F9FAFB' : '0', ms: noted ? '9px' : '16px'
    };
  });
  // Beside the bar, never over it, so the hovered disc stays visible.
  const cx = bars.cols[hb.i].cx; const at = r1(cx / FN.W * 100) + '%';
  const side = cx < FN.W / 2 ? 'calc(' + at + ' + 16px)' : 'calc(' + at + ' - 236px)';
  return {
    show: true, title: bucketTitle(p, hb), total: hb.future ? 'Still ahead' : plural(hb.total, 'commit'), rows,
    entries, hasEntries: entries.length > 0, more: items.length > 4, moreText: '+' + (items.length - 4) + ' more',
    left: 'clamp(0px, ' + side + ', calc(100% - 220px))'
  };
}

// What the pointer or keyboard is on: a bucket for the tooltip (st.hover) and
// the notes to light up (ui.lit), with the handlers that set them. A jump
// flashes its row: amber in, then out over a second. Each transition's end
// moves the row to the next step (ui.flash is n, then -n, then null), so no
// timer can race with other updates.
function interactionOf(ctx, bucketCount) {
  const { st, set } = ctx; const ui = st.ui || {};
  const setUi = patch => set({ ui: Object.assign({}, st.ui, patch) });
  const lit = ui.lit && ui.lit.b < bucketCount ? ui.lit : null;
  const hover = st.hover != null && st.hover >= 0 && st.hover < bucketCount ? st.hover : null;
  return {
    ui, setUi, lit, litNotes: lit ? lit.notes : [], hover, washB: hover != null ? hover : lit ? lit.b : null,
    showBucket: i => { if (st.hover !== i || ui.lit) set({ hover: i, ui: Object.assign({}, st.ui, { lit: null }) }); },
    light: (b, notes, withTip) => set({ hover: withTip ? b : st.hover, ui: Object.assign({}, st.ui, { lit: { b, notes } }) }),
    clear: () => { if (st.hover != null || ui.lit) set({ hover: null, ui: Object.assign({}, st.ui, { lit: null }) }); },
    unlight: () => { if (ui.lit) setUi({ lit: null }); },
    jump: n => setUi({ flash: n }),
    flashNext: n => { if (ui.flash === n) setUi({ flash: -n }); else if (ui.flash === -n) setUi({ flash: null }); }
  };
}

function chartView(ctx, ix, bs, bars, ds) {
  const { p, names, proj } = ctx;
  const pct = (v, of) => Math.round(v / of * 10000) / 100 + '%';
  const px = v => pct(v, FN.W); const py = v => pct(v, FN.H);
  const unit = p.unit === 'day' ? 'day' : p.unit === 'week' ? 'week' : 'month';
  const hb = ix.hover != null ? bs[ix.hover] : null;

  const c = {
    gridD: bars.grid.map(t => 'M' + FN.L + ',' + t.y + 'H' + FN.R).join(''),
    baseD: 'M' + FN.L + ',' + FN.B + 'H' + FN.R,
    washD: ix.washB == null ? '' : box(FN.L + bars.slot * ix.washB + 1, 2, bars.slot - 2, FN.B - 2),
    fills: bars.fills
  };
  const ticks = bars.grid.map(t => ({ v: t.v, top: py(t.y) }));
  // Month labels crowd a narrow column: below 600px every other one steps aside,
  // and so do the two beside the current month, which always stays.
  const crowded = p.range === 'year' || p.range === 'all';
  const named = bs.map((b, i) => ({ text: axisLabel(p, bs, i), tone: toneOf(p, bs, i), left: px(bars.cols[i].cx) })).filter(l => l.text);
  const now = named.findIndex(l => l.tone === 'now');
  const xls = named.map((l, k) => ({
    text: l.text, left: l.left, color: l.tone === 'now' ? PAGE.ink : l.tone === 'future' ? PAGE.quiet : PAGE.faint, fw: l.tone === 'now' ? '600' : '400',
    size: crowded && l.tone !== 'now' && (k % 2 || (now >= 0 && Math.abs(k - now) === 1)) ? fnStep(0, 11) : '11px'
  }));
  const hits = bars.cols.map((col, i) => ({ left: px(FN.L + bars.slot * i), width: px(bars.slot), enter: () => ix.showBucket(i) }));
  const discs = ds.map(d => {
    const on = !!ix.lit && ix.lit.b === d.i;
    return {
      left: px(d.x), top: py(d.cy), label: d.label, href: '#note-' + d.first, aria: discLabelOf(d),
      w: d.notes.length > 1 ? fnStep(13, FN.pill) : fnStep(8, FN.disc), hit: d.notes.length > 1 ? fnStep(24, FN.pill + 8) : '24px',
      bg: d.ship ? PAGE.ink : '#ffffff', fg: d.ship ? '#ffffff' : PAGE.ink, border: d.ship ? '0' : '1.5px solid ' + PAGE.ink,
      shadow: on ? '0 0 0 2px #ffffff, 0 0 0 4px ' + PAGE.ink : '0 0 0 2px #ffffff',
      enter: () => ix.light(d.i, d.notes.map(o => o.n), true), blur: ix.clear, go: () => ix.jump(d.first)
    };
  });
  const tip = hb ? tooltipOf(p, hb, bars, ds, ix.litNotes) : { show: false, rows: [], entries: [], hasEntries: false, more: false, moreText: '', left: '0px', title: '', total: '' };
  return {
    c, ticks, xls, hits, discs, tip, leave: ix.clear,
    chartLabel: 'Commits per ' + unit + (proj == null ? ' by project' : ' in ' + DATA.projects[proj]) + ', ' + names.title
  };
}

// The legend names the biggest projects; "+N more" opens the rest.
function legendView(ctx, ix, key) {
  const { proj, sum, filterTo } = ctx;
  const order = sum.cur.counts.map((n, pi) => ({ n, pi })).filter(o => o.n > 0).sort((a, b) => b.n - a.n);
  const all = ix.ui.legend === key;
  const legend = (all ? order : order.slice(0, 5)).map(o => ({ name: DATA.projects[o.pi], n: o.n, color: colorOf(o.pi, 'page'), pick: filterTo(o.pi), hint: 'Show only ' + DATA.projects[o.pi] }));
  return {
    legendShow: proj == null && legend.length > 0, legend,
    legendMore: { show: proj == null && !all && order.length > 5, text: '+' + (order.length - 5) + ' more', toggle: () => ix.setUi({ legend: key }) }
  };
}

// The notes, numbered as on the chart, then the rest folded behind one row.
function listView(ctx, ix, ds, key) {
  const { owner, proj, p, names, picks, filterTo } = ctx;
  const discOf = {}; ds.forEach(d => d.notes.forEach(o => { discOf[o.n] = d; }));
  const notes = picks.kept.map((x, k) => {
    const n = k + 1; const ship = x.k === 's';
    return Object.assign(rowTextOf(x, proj, filterTo), {
      id: 'note-' + n, n: String(n),
      dbg: ship ? PAGE.ink : '#ffffff', dfg: ship ? '#ffffff' : PAGE.ink, dborder: ship ? '0' : '1.5px solid ' + PAGE.ink,
      bg: ix.ui.flash === n ? FLASH : ix.litNotes.indexOf(n) >= 0 ? PAGE.rule : 'transparent',
      fade: ix.ui.flash === -n ? '1s ease-in-out' : '0.15s',
      enter: () => ix.light(discOf[n].i, [n], false), leave: ix.unlight, next: () => ix.flashNext(n)
    });
  });
  const restOpen = ix.ui.rest === key && picks.left.length > 0;
  const phrase = phraseOf(p, names);
  return {
    title: 'Shipped and published ' + phrase + (proj != null ? ' · ' + DATA.projects[proj] : ''),
    key: notes.length > 0, notes,
    hasRest: picks.left.length > 0, restOpen,
    restText: picks.left.length + ' more ' + phrase, chevron: restOpen ? 'rotate(180deg)' : 'none',
    rest: restOpen ? picks.left.map(x => Object.assign(rowTextOf(x, proj, filterTo), { ship: x.k === 's', post: x.k !== 's' })) : [],
    toggleRest: () => ix.setUi({ rest: restOpen ? null : key }),
    empty: notes.length === 0, emptyText: proj != null ? names.emptyTagged : names.empty, log: owner && proj == null
  };
}

function optionView(ctx) {
  const { ents, proj, p } = ctx;
  // Open states belong to one period and filter; changing either closes them.
  const key = [p.range, p.offset, proj == null ? 'all' : proj].join(':');
  const bs = bucketsOf(p, proj, ents);
  const bars = barsOf(bs, FN, 'page');
  const ds = discsOf(bs, ctx.picks.kept, bars, FN);
  const ix = interactionOf(ctx, bs.length);
  return Object.assign(chartView(ctx, ix, bs, bars, ds), legendView(ctx, ix, key), { list: listView(ctx, ix, ds, key) });
}
