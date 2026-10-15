// ===== Journey engine =====
// One cumulative commits line with the builder's entries standing on it as
// markers and flags. The page chart (two profiles) and the card share this
// file, so a flag lands on the same bucket on every surface. Units are viewBox
// px on the page and artboard px on the card. Ported from the design-round
// prototype (journey/journey_proto.py), with the shared pick() as flag order.

// Geometry per surface. top/base: the 'top tick' and baseline y. lo/hi: where
// flags may go. rises: gaps between a marker halo and the flag above it.
const MARKS = { dia: 6, ring: 4.6, ringW: 2, halo: 2, gap: 7, rises: [6, 22, 38, 54], minBin: 12, num: 13, word: 13, dot: 4, endPad: 40, lineW: 2 };
const JG = {
  page: Object.assign({ id: 'page', W: 704, H: 248, L: 30, R: 698, top: 22, base: 220, lo: 4, hi: 216, fs: 13, lh: 16, mw: 180, caps: { week: 3, month: 3, year: 5, all: 5 } }, MARKS),
  mobile: Object.assign({ id: 'mobile', W: 360, H: 240, L: 26, R: 354, top: 22, base: 212, lo: 4, hi: 208, fs: 12.5, lh: 15, mw: 150, caps: { week: 2, month: 2, year: 3, all: 3 } }, MARKS, { num: 12.5, word: 12.5 }),
  card: { id: 'card', trims: true, W: 1200, H: 630, L: 100, R: 1140, top: 318, base: 552, lo: 282, hi: 548, fs: 20, lh: 24, mw: 290, dia: 8, ring: 6.2, ringW: 2.6, halo: 3, gap: 10, rises: [8, 28, 48, 68], minBin: 18, num: 24, word: 17, dot: 5, endPad: 72, lineW: 2.5, caps: { week: 3, month: 4, year: 6, all: 6 } }
};

// Round tick values on a commits axis. The step is a whole number: 2.5 only
// when it is 25 or more, so a small chart never shows half a commit.
function niceTicks(max) {
  const raw = max / 3; const p = Math.pow(10, Math.floor(Math.log10(raw))); const m = raw / p;
  const step = (m <= 1 ? 1 : m <= 2 ? 2 : m <= 2.5 && p >= 10 ? 2.5 : m <= 5 ? 5 : 10) * p;
  const top = Math.ceil(max / step - 1e-9) * step; const out = [];
  for (let v = 0; v <= top + 1e-9; v += step) out.push(Math.round(v * 10) / 10);
  return out;
}
function r2(v) { return Math.round(v * 100) / 100; }
function diamondPath(cx, cy, r) { return 'M' + r1(cx) + ',' + r1(cy - r) + 'L' + r1(cx + r) + ',' + r1(cy) + 'L' + r1(cx) + ',' + r1(cy + r) + 'L' + r1(cx - r) + ',' + r1(cy) + 'Z'; }
function circlePath(cx, cy, r) { return 'M' + r1(cx - r) + ',' + r1(cy) + 'a' + r + ',' + r + ' 0 1,0 ' + 2 * r + ',0a' + r + ',' + r + ' 0 1,0 ' + -2 * r + ',0Z'; }
function boxHits(a, b, px, py) { return !(a.x + a.w + px <= b.x || b.x + b.w + px <= a.x || a.y + a.h + py <= b.y || b.y + b.h + py <= a.y); }

// ----- domain, buckets, line -----

// First day with a commit or an entry (of the project under a filter), in all
// time; null when there is none.
function firstActivity(proj, ents) {
  const days = Object.keys(DATA.days).filter(k => proj == null || DATA.days[k].some(c => c[0] === proj)).map(ms);
  const dates = ents.filter(x => proj == null || x.r === proj).map(x => ms(x.d));
  const all = days.concat(dates);
  return all.length ? Math.min.apply(null, all) : null;
}

// The chart never shows time before the first activity: it starts one unit
// before it (a day in Week and Month, a month in Year and All), or at the
// period start if that is later. The card also stops a running period at
// today (Week, Month) or at the end of this month (Year, All).
function domainOf(p, proj, ents, g) {
  const first = firstActivity(proj, ents);
  const byDay = p.range === 'week' || p.range === 'month';
  const q = parts(first == null ? p.start : first);
  const floor = first == null ? p.start : byDay ? first - DAY : mStart(q.y, q.m - 1);
  let s = p.range === 'all' ? floor : Math.max(p.start, floor);
  let e = p.end;
  if (s > e) s = p.start;
  if (g.trims && running(p)) e = byDay ? T0 : mStart(parts(T0).y, parts(T0).m + 1) - DAY;
  return { s, e, days: Math.round((e - s) / DAY) + 1, byDay };
}

// A day each, an ISO week each (clipped to the domain), or a calendar month each.
function binsOf(dom, unit) {
  const out = [];
  if (unit === 'day') { for (let s = dom.s; s <= dom.e; s += DAY) out.push({ s, e: s }); }
  else if (unit === 'week') { for (let w = dom.s - parts(dom.s).wd * DAY; w <= dom.e; w += 7 * DAY) out.push({ s: Math.max(w, dom.s), e: Math.min(w + 6 * DAY, dom.e) }); }
  else { for (let d = mStart(parts(dom.s).y, parts(dom.s).m); d <= dom.e;) { const q = parts(d); const nxt = mStart(q.y, q.m + 1); out.push({ s: Math.max(d, dom.s), e: Math.min(nxt - DAY, dom.e) }); d = nxt; } }
  return out;
}
// Markers sit one per bucket; a bucket narrower than minBin px steps up a unit.
function markerUnit(dom, g) {
  const perDay = (g.R - g.L) / dom.days;
  if (perDay * 7 < g.minBin) return 'month';
  return dom.byDay && perDay < g.minBin ? 'week' : dom.byDay ? 'day' : 'week';
}

// Cumulative commits at the end of every bucket up to today. t counts days
// from the domain start, so a bucket's end vertex sits at t.
function lineOf(dom, proj, ents) {
  const pts = [{ t: 0, v: 0 }]; const buckets = []; let cum = 0;
  binsOf(dom, dom.byDay ? 'day' : 'week').forEach(b => {
    if (b.s > T0) return;
    const e = Math.min(b.e, T0); const got = tally(b.s, e, proj, ents);
    cum += got.total;
    const t = Math.round((e - dom.s) / DAY) + 1;
    pts.push({ t, v: cum });
    buckets.push({ i: buckets.length, s: b.s, e, full: b.e, t, cum, total: got.total, counts: got.counts, hl: got.hl });
  });
  return { pts, buckets, total: cum };
}

// ----- text -----

function chartTitle(t) { return stripEmoji(t).replace(/(\w)'(\w)/g, '$1’$2'); }
function weightOf(x) { return x.pin ? 600 : x.k === 's' ? 500 : 400; }

// How a title can be set: one line if it fits the measure; two balanced lines
// when the title is wider than 60% of the measure (and the pair is clearly
// narrower); a word cut with "…" when it needs more. A title ending in ":"
// also gets its own body as a muted run-in, only in the room the last line has
// left, so it never adds a line. Plain versions come after the run-in ones.
function flagTexts(x, g) {
  const weight = weightOf(x); const text = chartTitle(x.t);
  const w1 = measure(text, weight, g.fs);
  const two = wrapText(text, weight, g.fs, Math.min(g.mw, w1 - 0.5), 2);
  const shapes = [];
  if (w1 <= g.mw) shapes.push([text]);
  if (two.lines.length === 2 && (!shapes.length || (w1 > 0.6 * g.mw && Math.max.apply(null, two.widths) < 0.8 * w1))) shapes.push(two.lines);
  if (!shapes.length) shapes.push(two.lines);
  const body = runInOf(x); const out = [];
  shapes.forEach(lines => {
    const widths = lines.map(l => measure(l, weight, g.fs)); const last = widths[widths.length - 1]; const h = lines.length * g.lh;
    const gap = measure(' ', weight, g.fs);
    const run = body ? fitRunIn(chartTitle(body), g.mw - last - gap, 400, g.fs) : '';
    if (run) out.push({ lines, run, w: Math.max.apply(null, widths.slice(0, -1).concat(last + gap + measure(run, 400, g.fs))), h });
    out.push({ lines, run: '', w: Math.max.apply(null, widths), h });
  });
  return out;
}

// ----- flags -----

// Every try for one flag, cheapest first: the pole gap plus the text height,
// with a penalty on a second line when one line would do. Left of the marker
// goes first on a rising line.
function flagTries(m, texts, g) {
  const oneLine = texts.some(v => v.lines.length === 1);
  const leftFirst = m.rising || m.x - g.L > g.R - m.x;
  const sides = leftFirst ? ['L', 'R'] : ['R', 'L'];
  const out = [];
  texts.forEach((v, vi) => g.rises.forEach(rise => sides.forEach((side, si) => {
    out.push({ v, vi, rise, side, si, cost: rise + v.h + (oneLine && v.lines.length === 2 ? 1.5 * g.lh : 0) });
  })));
  return out.sort((a, b) => a.cost - b.cost || a.vi - b.vi || a.si - b.si);
}

// Entries are tried in pick order, one flag per bucket, until the cap. A marker
// whose first entry fits nowhere stays bare and the next one is tried. A flag
// stays inside the plot, 3px clear above the line across its width, 6px from
// other flags, poles and markers, clear of the end label, and its pole never
// crosses another flag.
function placeFlags(g, L, order, cap) {
  const halo = m => (m.ship ? g.dia : g.ring + g.ringW / 2) + g.halo;
  const obstacles = L.markers.map(m => ({ x: m.x - halo(m), y: m.y - halo(m), w: 2 * halo(m), h: 2 * halo(m), kind: 'marker', m }));
  const dot = g.dot + g.halo;
  obstacles.push({ x: L.ex - dot, y: L.ey - dot, w: 2 * dot, h: 2 * dot, kind: 'end' }, Object.assign({ kind: 'endlabel' }, L.endBox));
  const clearOfLine = b => {
    for (let x = b.x - 3; x <= b.x + b.w + 3; x += 1.5) { const y = L.lineY(x); if (y != null && y < b.y + b.h + 3) return false; }
    return !L.line.some(q => q.x >= b.x - 3 && q.x <= b.x + b.w + 3 && q.y < b.y + b.h + 3);
  };
  const clashes = (b, pole, o) => {
    if (boxHits(b, o, o.kind === 'endlabel' ? g.endPad : 6, o.kind === 'endlabel' ? 8 : 3)) return true;
    return (o.kind === 'flag' || o.kind === 'endlabel') && boxHits(pole, o, 2, 2);
  };
  const place = (m, x) => {
    const r = halo(m);
    for (const c of flagTries(m, flagTexts(x, g), g)) {
      const by = m.y - r - c.rise - c.v.h; const bx = c.side === 'L' ? m.x - g.gap - c.v.w : m.x + g.gap;
      const b = { x: bx, y: by, w: c.v.w, h: c.v.h, kind: 'flag' };
      if (bx < g.L + 2 || bx + b.w > g.R || by < g.lo || by + b.h > g.hi || !clearOfLine(b)) continue;
      const pole = { x: m.x - 2.5, y: by, w: 5, h: m.y - r - by };
      if (obstacles.some(o => o.m !== m && clashes(b, pole, o))) continue;
      obstacles.push(b, pole);
      return { m, entry: x, v: c.v, side: c.side, bx, by, w: b.w, h: b.h, pole: { x: m.x, y0: m.y - r, y1: by + 1 } };
    }
    return null;
  };
  const flags = []; const tried = new Set();
  order.forEach(x => {
    const m = L.markers.find(k => k.ids.has(x.id));
    if (!m || tried.has(m) || flags.length >= cap) return;
    const f = place(m, x);
    if (f) { m.flag = f; flags.push(f); tried.add(m); } else if (!x.swapped) tried.add(m);
  });
  return flags;
}

// The order flags are tried in: pins, then what the owner swapped in, then
// every other entry in pick order. Flags are taken from the front until the
// cap, so a swap pushes the lowest-ranked unpinned flag out. A swapped-in entry
// that fits nowhere hands its bucket back to the next entry (see placeFlags).
function flagOrder(p, proj, ents, feature) {
  const all = pick(p, proj, DATA.entries.length, ents, []).rank || [];
  const want = feature || [];
  const swapped = want.map(id => all.find(x => x.id === id && !x.pin)).filter(Boolean).map(x => Object.assign({}, x, { swapped: true }));
  const rest = all.filter(x => x.pin || want.indexOf(x.id) < 0);
  return rest.filter(x => x.pin).concat(swapped, rest.filter(x => !x.pin));
}

// ----- the whole chart -----

// The end label sits 10px right of the end dot while the period still has
// room, else above and left of it (never above the top of the chart). Beside a
// dot on the baseline (nothing committed yet) it lifts clear of the axis and its
// day labels instead of straddling them.
function endLabelOf(g, total, ex, ey, room) {
  const word = ' commit' + (total === 1 ? '' : 's');
  const w = measure(String(total), 600, g.num) + measure(word, 400, g.word); const h = g.num * 1.25;
  const right = room && ex + 10 + w <= g.R;
  return { x: right ? ex + 10 : Math.min(ex - 4, g.R) - w, y: right ? Math.min(ey - h / 2, g.base - 4 - h) : Math.max(0, ey - 12 - h), w, h, num: String(total), word };
}

// A week names every day. A month names its week starts (1, 8, 15, 22, 29) and
// today. A month that refits to a late first commit can hold fewer than three of
// those, so it names every day instead (every 2nd or 3rd on a longer one) and the
// axis never goes bare.
function axisLabels(p, dom, X) {
  const out = [];
  if (dom.byDay) {
    const bins = binsOf(dom, 'day'); const weekStart = q => [1, 8, 15, 22, 29].indexOf(q.d) >= 0;
    const dense = p.range === 'month' && bins.filter(b => weekStart(parts(b.s))).length < 3;
    const step = !dense ? 0 : bins.length <= 9 ? 1 : bins.length <= 16 ? 2 : 3;
    bins.forEach((b, i) => {
      const q = parts(b.s); const today = b.s === T0;
      const named = p.range === 'week' || today || (step ? i % step === 0 : weekStart(q));
      const text = !named ? '' : p.range === 'week' ? WD[q.wd] + ' ' + q.d : q.d === 1 ? MON[q.m] + ' 1' : String(q.d);
      if (text) out.push({ x: X(i + 0.5), text, today, future: b.s > T0 });
    });
  } else {
    binsOf(dom, 'month').forEach((b, i) => {
      const q = parts(b.s); const nxt = mStart(q.y, q.m + 1);
      out.push({ x: X(((b.s - dom.s) + (b.e + DAY - dom.s)) / 2 / DAY), text: MON[q.m] + (p.range === 'all' && (i === 0 || q.m === 0) ? ' ' + q.y : ''), today: b.s <= T0 && T0 < nxt, future: b.s > T0 });
    });
  }
  return out;
}
// Drops a label that would touch the one after it, so a narrow chart stays legible.
function declutter(labels, width, gap) {
  const kept = [];
  for (let i = labels.length - 1; i >= 0; i--) {
    const l = labels[i]; const w = width(l); const last = kept[kept.length - 1];
    if (!last || last.x - last.w / 2 - gap >= l.x + w / 2) kept.push(Object.assign({}, l, { w }));
  }
  return kept.reverse();
}

function lineYOf(line) {
  return x => {
    if (x < line[0].x) return line[0].y;
    for (let i = 1; i < line.length; i++) {
      const a = line[i - 1], b = line[i];
      if (x >= a.x && x <= b.x) return b.x === a.x ? a.y : a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x);
    }
    return null;
  };
}

// The pool is the period's entries (of the project under a filter); order is
// the pick order that decides which of them get words.
function journeyLayout(p, proj, ents, g, order) {
  const dom = domainOf(p, proj, ents, g);
  const X = t => g.L + t / dom.days * (g.R - g.L);
  const { pts, buckets, total } = lineOf(dom, proj, ents);
  const ticks = niceTicks(Math.max(4, total)); const top = ticks[ticks.length - 1];
  const Y = v => g.base - v / top * (g.base - g.top);
  const line = pts.map(q => ({ x: X(q.t), y: Y(q.v) }));
  const lineY = lineYOf(line); const end = line[line.length - 1];
  // x0 is where a bucket starts, x where it ends (its vertex).
  buckets.forEach(b => { b.x = X(b.t); b.y = Y(b.cum); b.x0 = X(b.t - Math.round((b.e - b.s) / DAY) - 1); });
  const pool = ents.filter(x => { const t = ms(x.d); return t >= p.start && t <= lastDay(p) && (proj == null || x.r === proj); });
  const markers = binsOf(dom, markerUnit(dom, g)).map(b => {
    const es = pool.filter(x => { const t = ms(x.d); return t >= b.s && t <= b.e; });
    if (!es.length) return null;
    const last = Math.min(b.e, T0);
    const x = Math.min(X((b.s - dom.s) / DAY + ((last - b.s) / DAY + 1) / 2), end.x);
    const rising = lineY(Math.min(x + 4, end.x)) < lineY(Math.max(x - 4, line[0].x)) - 0.01;
    return { x, y: lineY(x), bin: b, entries: es, ids: new Set(es.map(e => e.id)), ship: es.some(e => e.k === 's'), rising };
  }).filter(Boolean);
  const endBox = endLabelOf(g, total, end.x, end.y, running(p) && dom.e > T0);
  const L = { g, dom, X, Y, ticks, line, lineY, buckets, total, markers, pool, ex: end.x, ey: end.y, endBox, flags: [] };
  L.flags = placeFlags(g, L, order, g.caps[p.range]);
  L.labels = axisLabels(p, dom, X);
  return L;
}
// ===== end of Journey engine =====
