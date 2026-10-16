// ===== Journey line: card =====
const OPTION = { key: 'journey', cap: range => JG.page.caps[range], cardCap: range => JG.card.caps[range], glyphs: 'diamond' };

const POLE = { light: '#BDBBB1', dark: '#4A5258' };
const STAT_X = [672, 790, 908, 1026];

// Top of a box whose first baseline must land on y. Inter and DM Mono ascent and
// descent as the browser reports them, in em.
const FONT_EM = { inter: { up: 0.97, body: 1.21 }, mono: { up: 0.99, body: 1.3 } };
function topFor(baseline, size, lh, font) { const f = FONT_EM[font]; return r1(baseline - ((lh - f.body * size) / 2 + f.up * size)); }

const STAT_TOP = { value: topFor(214, 30, 36, 'inter'), label: topFor(236, 11, 14, 'mono') };   // value baseline 214, label baseline 236

// The empty-state line sits at the top-left of the plot. When the line climbs into
// that corner (a filtered project that took off early) it moves up, above the top tick,
// where the line never goes.
function quietTop(L, text) {
  const w = measure(text, 500, 20); const x0 = JG.card.L, x1 = JG.card.L + w + 3;
  for (const top of [328, 288]) {
    const low = top + 24 + 3;
    let clear = !L.line.some(q => q.x >= x0 && q.x <= x1 && q.y < low);
    for (let x = x0; clear && x <= x1; x += 3) { const y = L.lineY(x); if (y != null && y < low) clear = false; }
    if (clear) return top;
  }
  return 288;
}

function parseJson(s) { try { const v = JSON.parse(s); return v && typeof v === 'object' ? v : {}; } catch (e) { return {}; } }
function parseIds(s) { return String(s || '').split(',').map(Number).filter(n => isFinite(n) && n > 0); }

function quietOf(L, text) { return { show: L.pool.length === 0, text, top: quietTop(L, text) }; }

function statsOf(sum, t) {
  const cur = sum.cur; const pr = sum.prev;
  return [['SHIPPED', 'shipped', 'diamond'], ['PUBLISHED', 'published', 'ring'], ['COMMITS', 'total', ''], ['ACTIVE DAYS', 'active', '']].map(([label, key, glyph], i) => {
    const dl = pr && deltaOf(cur[key], pr[key]);
    return {
      label, value: cur[key], left: STAT_X[i], valueTop: STAT_TOP.value, labelTop: STAT_TOP.label,
      diamond: glyph === 'diamond', ring: glyph === 'ring', has: !!dl, dText: dl ? dl.text : '', dColor: dl && dl.up ? t.accent : t.faint
    };
  });
}

function flagBlocks(L, t) {
  const g = L.g;
  return L.flags.map(f => {
    const right = f.side === 'L';
    return {
      left: right ? 'auto' : f.bx + 'px', right: right ? (g.W - (f.bx + f.w)) + 'px' : 'auto', top: r1(f.by), align: right ? 'right' : 'left',
      fw: weightOf(f.entry), color: f.entry.k === 's' || f.entry.pin ? t.ink : t.muted,
      lines: f.v.lines.map((text, i) => ({ text, run: i === f.v.lines.length - 1 ? f.v.run : '', hasRun: i === f.v.lines.length - 1 && !!f.v.run }))
    };
  });
}

class Component extends DCLogic {
  renderVals() {
    const pr = this.props;
    const range = ['week', 'month', 'year', 'all'].indexOf(pr.range) >= 0 ? pr.range : 'year';
    const theme = pr.theme === 'dark' ? 'dark' : 'light';
    const offset = range === 'all' ? 0 : Math.min(0, Number(pr.offset) || 0);
    const proj = pr.project !== '' && pr.project != null && Number(pr.project) >= 0 && Number(pr.project) < DATA.projects.length ? Number(pr.project) : null;
    const t = THEMES[theme]; const g = JG.card;
    const ents = entriesWith(parseJson(pr.tags));
    const p = periodOf(range, offset);
    const names = namesOf(p, proj); const sum = summaryOf(p, proj, ents);
    // The card says "yet" while the period is still running, as the empty week does.
    const tagged = names.running && range !== 'all' ? names.emptyTagged.replace(/\.$/, ' yet.') : names.emptyTagged;
    const L = journeyLayout(p, proj, ents, g, flagOrder(p, proj, ents, parseIds(pr.feature)));
    const filtered = proj != null;
    const washColor = filtered ? colorOf(proj, theme) : t.ink;
    const first = L.line[0], last = L.line[L.line.length - 1];
    const lineD = 'M' + L.line.map(q => r1(q.x) + ',' + r1(q.y)).join('L');
    const post = L.markers.filter(m => !m.ship);
    const labels = declutter(L.labels, l => monoW(l.text.toUpperCase(), 11, 0.08), 8);
    const e = L.endBox;
    const c = {
      gridD: L.ticks.slice(1).map(v => 'M' + g.L + ',' + r1(L.Y(v)) + 'H' + g.R).join(''), baseD: 'M' + g.L + ',' + g.base + 'H' + g.R,
      washD: lineD + 'L' + r1(last.x) + ',' + g.base + 'L' + r1(first.x) + ',' + g.base + 'Z', lineD,
      washColor, wash0: filtered ? 0.22 : 0.1, wash1: filtered ? 0.04 : 0.02, lineW: g.lineW, ringW: g.ringW, haloW: 2 * g.halo,
      poleD: L.flags.map(f => 'M' + r1(f.pole.x) + ',' + r1(f.pole.y0) + 'V' + r1(f.pole.y1)).join(''), pole: POLE[theme],
      haloD: post.map(m => circlePath(m.x, m.y, g.ring + g.ringW / 2 + g.halo)).join(''),
      shipD: L.markers.filter(m => m.ship).map(m => diamondPath(m.x, m.y, g.dia)).join(''), ringD: post.map(m => circlePath(m.x, m.y, g.ring)).join(''),
      dot: { cx: r1(L.ex), cy: r1(L.ey), r: g.dot }
    };
    return {
      t, c, names, stats: statsOf(sum, t), flags: flagBlocks(L, t),
      sub: { dot: filtered, color: filtered ? colorOf(proj, theme) : t.faint, slug: filtered ? DATA.projects[proj] : '', rest: filtered ? ' · ' + names.sub : names.sub },
      ticks: L.ticks.map(v => ({ v, top: r1(L.Y(v)) })),
      xls: labels.map(l => ({ text: l.text.toUpperCase(), left: r1(l.x), top: topFor(578, 11, 12, 'mono'), color: l.today ? t.ink : t.faint })),
      end: { left: r1(e.x), top: r1(e.y), lh: r1(e.h), num: e.num, word: e.word },
      quiet: quietOf(L, filtered ? tagged : names.empty)
    };
  }
}
// ===== end of Journey line: card =====
