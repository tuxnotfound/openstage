// ===== Journey line: page view =====
// The chart is drawn twice, in the 704 and 360 profiles; the chart box is a
// size container and each profile shows itself only in its own width range
// (a step function in container units, since a section has no stylesheet).
// Text is HTML over the SVG, sized in cqw so it scales with the chart.
const OPTION = { key: 'journey', cap: range => JG.page.caps[range], cardCap: range => JG.card.caps[range], glyphs: 'diamond' };
// The card dialog lists what the card really flags: the card's own layout
// decides which entries get words, so "Not on the card" and the post draft
// come from it rather than from a plain pick.
OPTION.cardEntries = (p, proj, ents, feature) => {
  const L = journeyLayout(p, proj, ents, JG.card, flagOrder(p, proj, ents, feature));
  const ids = new Set(L.flags.map(f => f.entry.id));
  const byDate = (a, b) => (a.d < b.d ? -1 : a.d > b.d ? 1 : a.id - b.id);
  return { kept: L.pool.filter(x => ids.has(x.id)).sort(byDate), left: L.pool.filter(x => !ids.has(x.id)).sort(byDate) };
};

const JR = { ui: {}, scrollTimer: null, markTimer: null };   // the latest ui state and the two timers, which outlive a render
const STEP = { page: 'calc((100cqw - 559.5px) * 100000)', mobile: 'calc((559.5px - 100cqw) * 100000)' };
const CHART_FONT = "Inter, ui-sans-serif, system-ui, -apple-system, 'Segoe UI', sans-serif";
const INTER_BASE = 0.865;   // baseline below the top of a 1-line-height Inter box, in em

function projectColor(pi) { return colorOf(pi, 'page'); }
function byNewest(a, b) { return a.d < b.d ? 1 : a.d > b.d ? -1 : b.id - a.id; }

// ----- one chart profile -----

// Sizes for a profile: font sizes scale with the chart; fixed sizes do not.
// Both fall to zero outside the profile's width range.
function sizesOf(g) {
  const on = STEP[g.id];
  return {
    pc: x => r2(x / g.W * 100) + '%', pcy: y => r2(y / g.H * 100) + '%',
    fs: px => 'clamp(0px, ' + on + ', ' + r2(px / g.W * 100) + 'cqw)',
    fixed: px => 'clamp(0px, ' + on + ', ' + px + 'px)',
    share: v => 'clamp(0px, ' + on + ', ' + r2(v / g.W * 100) + '%)',
    whole: 'clamp(0px, ' + on + ', 100%)'
  };
}

function markerAria(m, order) {
  const top = m.flag ? m.flag.entry : order.find(x => m.ids.has(x.id)) || m.entries[0];
  const more = m.entries.length > 1 ? ', and ' + (m.entries.length - 1) + ' more' : '';
  return (m.ship ? 'Shipped, ' : 'Published, ') + fmtDay(ms(top.d)) + ': ' + top.t + (top.pin ? ' (pinned)' : '') + more;
}

function chartPaths(L, ctx) {
  const g = L.g; const line = L.line; const first = line[0], last = line[line.length - 1];
  const lineD = 'M' + line.map(q => r1(q.x) + ',' + r1(q.y)).join('L');
  const ship = L.markers.filter(m => m.ship); const post = L.markers.filter(m => !m.ship);
  const hov = ctx.hov == null ? null : L.buckets[ctx.hov];
  const focus = ctx.focusId == null ? null : L.markers.find(m => m.ids.has(ctx.focusId));
  const haloR = m => (m.ship ? g.dia : g.ring + g.ringW / 2) + g.halo;
  return {
    gridD: L.ticks.slice(1).map(v => 'M' + g.L + ',' + r1(L.Y(v)) + 'H' + g.R).join(''), baseD: 'M' + g.L + ',' + g.base + 'H' + g.R,
    lineD, washD: lineD + 'L' + r1(last.x) + ',' + g.base + 'L' + r1(first.x) + ',' + g.base + 'Z',
    poleD: L.flags.map(f => 'M' + r1(f.pole.x) + ',' + r1(f.pole.y0) + 'V' + r1(f.pole.y1)).join(''),
    haloD: post.map(m => circlePath(m.x, m.y, haloR(m))).join(''),
    shipD: ship.map(m => diamondPath(m.x, m.y, g.dia)).join(''), ringD: post.map(m => circlePath(m.x, m.y, g.ring)).join(''),
    focusD: focus ? circlePath(focus.x, focus.y, haloR(focus) + 3.5) : '',
    crossD: hov ? 'M' + r1(hov.x) + ',' + (g.top - 10) + 'V' + g.base : '',
    crossRing: hov ? circlePath(hov.x, hov.y, 6) : '',
    dot: { cx: r1(L.ex), cy: r1(L.ey), r: g.dot }
  };
}

function chartOverlay(L, ctx, z) {
  const g = L.g;
  const ticks = L.ticks.map(v => ({ v, left: z.pc(g.L - 8), top: z.pcy(L.Y(v)), fs: z.fs(10) }));
  const labels = declutter(L.labels, l => measure(l.text, l.today ? 600 : 400, 11), 6);
  const xls = labels.map(l => ({ text: l.text, left: z.pc(l.x), top: z.pcy(g.base + 17 - 11 * INTER_BASE), fs: z.fs(11), color: l.today ? PAGE.ink : l.future ? PAGE.quiet : PAGE.faint, fw: l.today ? 600 : 400 }));
  const flags = L.flags.map(f => {
    const left = f.side === 'R'; const ink = f.entry.k === 's' || f.entry.pin || ctx.focusId != null && f.m.ids.has(ctx.focusId);
    return {
      left: left ? z.pc(f.bx) : 'auto', right: left ? 'auto' : z.pc(g.W - (f.bx + f.w)), top: z.pcy(f.by), align: left ? 'left' : 'right',
      fs: z.fs(g.fs), lh: z.fs(g.lh), fw: weightOf(f.entry), color: ink ? PAGE.ink : PAGE.muted,
      lines: f.v.lines.map((text, i) => ({ text, run: i === f.v.lines.length - 1 ? f.v.run : '', hasRun: i === f.v.lines.length - 1 && !!f.v.run })),
      click: ctx.markClick(f.m)
    };
  });
  const markers = L.markers.map(m => ({
    left: z.pc(m.x), top: z.pcy(m.y), size: z.fixed(24), aria: markerAria(m, ctx.order), tab: ctx.tab,
    click: ctx.markClick(m), focus: ctx.hoverMarker(m), enter: ctx.hoverMarker(m), blur: ctx.clearHover
  }));
  const hits = L.buckets.map(b => ({ left: z.pc(b.x0), width: z.share(b.x - b.x0), enter: ctx.hoverBucket(b.i) }));
  const e = L.endBox;
  const end = { left: z.pc(e.x), top: z.pcy(e.y), lh: z.fs(e.h), fsNum: z.fs(g.num), fsWord: z.fs(g.word), num: e.num, word: e.word };
  return { ticks, xls, flags, markers, hits, end };
}

function tipOf(L, ctx, z) {
  const b = ctx.hov == null ? null : L.buckets[ctx.hov];
  if (!b) return { show: false, rows: [], entries: [], say: '' };
  const g = L.g; const left = b.x < g.W / 2;
  const rank = id => ctx.order.findIndex(x => x.id === id);
  const es = b.hl.slice().sort((a, c) => rank(a.id) - rank(c.id));
  const rows = ctx.proj != null ? [] : b.counts.map((n, pi) => ({ n, pi })).filter(r => r.n > 0).sort((a, c) => c.n - a.n).map(r => ({ name: DATA.projects[r.pi], n: r.n, color: projectColor(r.pi) }));
  const entries = es.slice(0, 4).map(x => ({ t: x.t, ship: x.k === 's', post: x.k === 'p', pin: !!x.pin, chip: x.r != null, slug: x.r != null ? DATA.projects[x.r] : '', color: x.r != null ? projectColor(x.r) : PAGE.faint }));
  const x = z.pc(b.x);
  const title = ctx.dom.byDay ? WD[parts(b.s).wd] + ', ' + fmtDay(b.s) : 'Week of ' + span(b.s, b.full);
  const value = b.total === 0 ? 'No commits' : '+' + plural(b.total, 'commit'); const sofar = b.cum + ' so far' + (ctx.p.range === 'all' ? '' : ' ' + ctx.names.word);
  // What a screen reader hears when the crosshair moves: the same facts as the tooltip.
  const say = [title, value + ', ' + sofar].concat(es.slice(0, 4).map(x => (x.k === 's' ? 'Shipped: ' : 'Published: ') + x.t + (x.pin ? ' (pinned)' : '')), es.length > 4 ? ['and ' + (es.length - 4) + ' more in the list'] : []).join('. ');
  return {
    show: true, rows, entries, hasEntries: es.length > 0, more: es.length > 4, moreText: '+' + (es.length - 4) + ' more in the list', say,
    fs: z.fixed(12), title, value, sofar,
    left: left ? 'max(0px, min(calc(' + x + ' + 12px), calc(100% - 220px)))' : 'max(0px, min(calc(' + x + ' - 232px), calc(100% - 220px)))'
  };
}

function chartView(L, ctx) {
  const g = L.g; const z = sizesOf(g); const filtered = ctx.proj != null;
  return Object.assign({
    id: g.id, W: g.W, H: g.H, svgW: z.whole, lineW: g.lineW, ringW: g.ringW, haloW: 2 * g.halo,
    washColor: filtered ? projectColor(ctx.proj) : PAGE.ink, wash0: filtered ? 0.22 : 0.1, wash1: filtered ? 0.04 : 0.02
  }, chartPaths(L, ctx), chartOverlay(L, ctx, z), { tip: tipOf(L, ctx, z) });
}

// ----- below the chart -----

function mixOf(ctx) {
  const items = ctx.sum.cur.counts.map((n, pi) => ({ n, pi })).filter(x => x.n > 0).sort((a, b) => b.n - a.n);
  const shown = items.slice(0, 5).map((x, i, all) => ({ name: DATA.projects[x.pi], n: x.n, color: projectColor(x.pi), hint: 'Show only ' + DATA.projects[x.pi], pick: ctx.filterTo(x.pi), sep: i < all.length - 1 || items.length > 5 }));
  return { show: ctx.proj == null && items.length > 0, items: shown, more: items.length > 5, moreText: '+' + (items.length - 5) + ' more' };
}

// One row per vertex bucket that has commits, so the table says what the chart shows.
function tableOf(L, ctx) {
  const rows = L.buckets.filter(b => b.total > 0).map(b => ({
    when: ctx.dom.byDay ? WD[parts(b.s).wd] + ', ' + fmtDay(b.s) : span(b.s, b.full), total: b.total, cum: b.cum,
    by: b.counts.map((n, pi) => ({ n, pi })).filter(r => r.n > 0).sort((a, c) => c.n - a.n).map(r => DATA.projects[r.pi] + ' ' + r.n).join(' · ')
  }));
  const open = !!ctx.ui.table;
  return { open, label: open ? 'Hide table' : 'Show as table', rows, toggle: () => ctx.setUi({ table: !open }) };
}

function listOf(ctx) {
  const items = ctx.pool.slice().sort(byNewest).map(x => ({
    id: x.id, t: x.t, date: fmtDay(ms(x.d)).toUpperCase(), ship: x.k === 's', post: x.k === 'p', pin: !!x.pin,
    chip: x.r != null, slug: x.r != null ? DATA.projects[x.r] : '', color: x.r != null ? projectColor(x.r) : PAGE.faint,
    bg: ctx.marked.has(x.id) ? PAGE.rule : 'transparent', enter: () => ctx.setUi({ row: x.id })
  }));
  return { show: items.length > 0, title: 'Shipped and published ' + ctx.names.word, items, leave: () => { if (ctx.ui.row != null) ctx.setUi({ row: null }); } };
}

function emptyOf(ctx) {
  const none = ctx.pool.length === 0;
  return { show: none, text: ctx.proj != null ? ctx.names.emptyTagged : ctx.names.empty, log: none && ctx.owner };
}

// ----- the view -----

// Handlers that change state. ui is merged from the latest render, because the
// timers here outlive the render that made them.
function handlersOf(ctx, main) {
  const { st, set } = ctx;
  const setUi = patch => set({ ui: Object.assign({}, JR.ui, patch) });
  const bucketOf = m => { const t = ms(m.entries[0].d); const b = main.buckets.find(k => t >= k.s && t <= k.e); return b ? b.i : null; };
  // The list rows live in the same tree as the chart, so they are looked up from the
  // clicked node's root: that works in the page and inside a shadow root alike.
  const scrollTo = (root, id) => {
    const tree = root && root.getElementById ? root : typeof document !== 'undefined' ? document : null;
    const el = tree && tree.getElementById('jr-row-' + id);
    const calm = typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (el && el.scrollIntoView) el.scrollIntoView({ block: 'center', behavior: calm ? 'auto' : 'smooth' });
  };
  return {
    setUi,
    hoverBucket: i => () => { if (st.hover !== i) set({ hover: i }); },
    clearHover: () => { if (st.hover != null) set({ hover: null }); },
    hoverMarker: m => () => { const i = bucketOf(m); if (i != null && st.hover !== i) set({ hover: i }); },
    // A marker or its flag lights up its rows for 1.5s and scrolls the first into view.
    // A second click restarts the 1.5s instead of letting the first timer cut it short.
    markClick: m => e => {
      const ids = m.entries.map(x => x.id); setUi({ mark: ids });
      if (typeof setTimeout !== 'function') return;
      const root = e && e.currentTarget && e.currentTarget.getRootNode ? e.currentTarget.getRootNode() : null;
      if (typeof clearTimeout === 'function') { clearTimeout(JR.scrollTimer); clearTimeout(JR.markTimer); }
      JR.scrollTimer = setTimeout(() => scrollTo(root, ids[0]), 40);
      JR.markTimer = setTimeout(() => setUi({ mark: null }), 1500);
    }
  };
}

// Left and right move the crosshair bucket by bucket (the first press lands on
// today), Escape hides the tooltip.
function keyHandler(st, set, last) {
  return e => {
    const k = e && e.key;
    if (last < 0) return;
    if (k === 'Escape') { set({ hover: null }); return; }
    const step = k === 'ArrowLeft' ? -1 : k === 'ArrowRight' ? 1 : 0;
    if (!step) return;
    if (e.preventDefault) e.preventDefault();
    set({ hover: st.hover == null ? last : Math.max(0, Math.min(last, st.hover + step)) });
  };
}

// Focusing the plot itself (not a marker inside it) shows the crosshair on the
// latest bucket, so a keyboard user sees where the arrows start.
function focusHandler(st, set, last) {
  return e => { if (last >= 0 && st.hover == null && e && e.target === e.currentTarget) set({ hover: last }); };
}

function chartLabelOf(ctx) {
  const { p, proj, names } = ctx; const cur = ctx.sum.cur; const n = cur.shipped + cur.published;
  const when = p.range === 'all' ? 'in all time' : (names.running ? 'so far in ' : 'in ') + names.title;
  return (proj != null ? DATA.projects[proj] + ' commits ' : 'Commits ') + when + ': ' + cur.total + '; ' + cur.shipped + ' shipped and ' + cur.published + ' published ' + (n === 1 ? 'entry' : 'entries');
}

function optionView(ctx) {
  const { st, set, ents, proj, p } = ctx;
  const ui = st.ui || {}; JR.ui = ui;
  const order = flagOrder(p, proj, ents, []);
  const layouts = [journeyLayout(p, proj, ents, JG.page, order), journeyLayout(p, proj, ents, JG.mobile, order)];
  const main = layouts[0];
  const c = Object.assign({
    p, proj, names: ctx.names, sum: ctx.sum, owner: ctx.owner, filterTo: ctx.filterTo, order, ui, pool: main.pool, dom: main.dom,
    hov: st.hover != null && st.hover >= 0 && st.hover < main.buckets.length ? st.hover : null,
    marked: new Set(ui.mark || []), focusId: ui.row == null ? null : ui.row
  }, handlersOf(ctx, main));
  const variants = layouts.map((L, i) => chartView(L, Object.assign({ tab: i === 0 ? 0 : -1 }, c)));
  return {
    variants, say: variants[0].tip.say,
    mix: mixOf(c), table: tableOf(main, c), list: listOf(c), empty: emptyOf(c),
    boxH: 'max(' + r2(JG.page.H / JG.page.W * 100) + 'cqw, clamp(0px, ' + STEP.mobile + ', ' + r2(JG.mobile.H / JG.mobile.W * 100) + 'cqw))',
    font: CHART_FONT, chartLabel: chartLabelOf(c),
    plotLabel: 'Commits chart. The left and right arrow keys move between ' + (main.dom.byDay ? 'days' : 'weeks') + ' and Escape closes the details.',
    leave: c.clearHover, key: keyHandler(st, set, main.buckets.length - 1), focus: focusHandler(st, set, main.buckets.length - 1)
  };
}
// ===== end of Journey line: page view =====
