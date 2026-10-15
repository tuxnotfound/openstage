// ===== Openstage progress draft: shared core =====
// Data (Tux's live page, to 2026-10-14), periods, the shared pick, the project
// filter with tag overrides, colors, and card text fitting with the server's
// Inter width tables. Paste verbatim at the top of every artboard script.
const DATA = {
  projects: ['openstage', 'wheels-off', 'goal_atlas', 'story_time_v1', 'trained-on', 'watchtower', 'trained-on-dataset'],
  days: {"2026-03-26":[[0,5]],"2026-03-27":[[0,1]],"2026-03-28":[[0,9]],"2026-03-31":[[0,1]],"2026-04-04":[[0,1]],"2026-04-29":[[0,1]],"2026-04-30":[[3,2]],"2026-05-01":[[3,1]],"2026-05-02":[[0,1],[3,3]],"2026-05-04":[[0,10]],"2026-05-05":[[0,15]],"2026-05-06":[[0,2],[3,19]],"2026-05-07":[[0,4]],"2026-05-08":[[0,2]],"2026-05-09":[[0,2]],"2026-05-10":[[3,1]],"2026-05-13":[[0,1]],"2026-05-14":[[3,3]],"2026-05-19":[[0,2],[2,1]],"2026-05-26":[[2,3]],"2026-05-27":[[0,1],[2,1]],"2026-06-03":[[0,1],[2,1]],"2026-06-04":[[0,1],[2,1]],"2026-06-05":[[0,1]],"2026-06-10":[[2,11]],"2026-06-11":[[2,10]],"2026-06-13":[[2,5]],"2026-06-14":[[0,1],[2,2]],"2026-06-15":[[2,1]],"2026-06-16":[[2,1]],"2026-06-17":[[2,7]],"2026-06-18":[[2,1]],"2026-06-19":[[2,1]],"2026-06-20":[[2,2]],"2026-06-21":[[3,2]],"2026-06-25":[[2,2]],"2026-06-29":[[2,1]],"2026-06-30":[[2,6]],"2026-07-28":[[2,3]],"2026-09-10":[[0,2]],"2026-09-11":[[0,18]],"2026-09-15":[[0,2],[3,1]],"2026-09-17":[[0,1]],"2026-09-21":[[0,4]],"2026-09-22":[[0,1]],"2026-09-23":[[0,1]],"2026-09-24":[[4,1]],"2026-09-25":[[1,12],[4,1]],"2026-09-26":[[1,3]],"2026-09-28":[[0,5],[4,13]],"2026-09-29":[[0,4],[4,2]],"2026-09-30":[[4,6]],"2026-10-01":[[4,1]],"2026-10-02":[[4,1]],"2026-10-06":[[0,2],[1,4]],"2026-10-07":[[1,19]],"2026-10-08":[[1,8]],"2026-10-09":[[0,2],[4,5]],"2026-10-11":[[0,25],[1,4]],"2026-10-12":[[0,5],[1,2]],"2026-10-13":[[0,39],[1,10],[4,1],[5,11],[6,3]],"2026-10-14":[[0,3],[5,5]]},
  // k: 's' shipped (milestone, release), 'p' published (post, note, link).
  // r: project index when the entry is tagged. pin: pinned by the builder.
  entries: [
    { id: 1, d: '2026-03-23', k: 'p', t: "why i'm building this" },
    { id: 2, d: '2026-03-26', k: 's', t: 'day 1: it boots' },
    { id: 3, d: '2026-03-26', k: 'p', t: 'on picking rails in 2026' },
    { id: 4, d: '2026-03-27', k: 'p', t: 'the demo solves itself' },
    { id: 5, d: '2026-03-28', k: 's', t: 'We are live!!' },
    { id: 6, d: '2026-03-28', k: 'p', t: 'from idea to live' },
    { id: 7, d: '2026-03-31', k: 's', t: 'live on Hacker News' },
    { id: 8, d: '2026-04-29', k: 's', t: 'Pro tier shipped 🎉' },
    { id: 9, d: '2026-05-06', k: 's', t: 'First user signed up 🥳🥳🥳' },
    { id: 10, d: '2026-05-07', k: 's', t: 'story time is live! 🚀🚀🚀' },
    { id: 11, d: '2026-05-08', k: 's', t: 'Share on 𝕏 !' },
    { id: 12, d: '2026-06-11', k: 's', t: 'launched The Goal Atlas 🌍 — just in time for 2026' },
    { id: 13, d: '2026-09-11', k: 'p', t: "This week's build log: 5 commits in openstage.", b: "This week's build log: 5 commits in openstage.\n- Rebirth begins 🚀" },
    { id: 14, d: '2026-09-11', k: 's', t: 'Rebirth begins 🚀', pin: 1 },
    { id: 15, d: '2026-09-18', k: 'p', t: 'This week I went back to Story Time by adding a export to pdf feature. Also a lot of work on synchronising private github repos on Openstage. Fun fun!' },
    { id: 16, d: '2026-09-23', k: 'p', t: "Needed help to summarize my week's work and an easy way to publicly share what I've been building. Built a recap feature, and it's live." },
    { id: 17, d: '2026-09-25', k: 'p', t: 'Shipped this week:', b: "- A new feature in OpenStage to help me recap my week's work\n- A new project to keep track of each AI tool trained on your inputs\n- A skateboarding game proof of concept was brought closer to life" },
    { id: 18, d: '2026-10-01', k: 's', t: 'Trained on me is live!!', pin: 1, r: 4, b: "Is AI training on my prompts? Was it ever? And which vendors are?\nLet's find out!" },
    { id: 19, d: '2026-10-02', k: 'p', t: "This week's build log:", b: "- Trained on me is live!!\n\nopenstage\n- UI cleanup\n- Landing page redesign\n\nwheels-off\n- Rider improvement: chibi look, finer ink lines, board animation\n- Kickflip move\n- Smoother distance edges (MSAA + FXAA)" },
    { id: 20, d: '2026-10-09', k: 'p', t: 'What I worked on this week: 40 commits across 3 repos.', b: "wheels-off\n- Serve the game at playwheelsoff.com, workers.dev off\n- Serve the leaderboard API from the Worker\n\ntrained-on\n- Press page, and a citation on every change page\n\nopenstage\n- Blog: the relaunch story" }
  ],
  identity: { name: 'Tux', handle: 'tuxnotfound', avatar: '/_blob/59b36a5d4069a14bd0e0e68e44a14127' }
};
const TODAY = '2026-10-15';
const DAY = 86400000;
const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const MONTH = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const WD = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// Colors. Project colors are fixed by all-time commits (DATA.projects order).
const PAL = { light: ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#e87ba4', '#008300'], dark: ['#3987e5', '#d95926', '#199e70', '#c98500', '#d55181', '#008300'] };
const THEMES = {
  light: { bg: '#F8F7F3', ink: '#14171A', muted: '#62665F', faint: '#8A8E86', rule: '#E4E3DC', ruleStrong: '#CDCBC1', accent: '#00875A', ring: '#D9D7CE' },
  dark: { bg: '#0E1012', ink: '#ECEEEF', muted: '#8E959A', faint: '#6B7378', rule: '#22272B', ruleStrong: '#394046', accent: '#00BA7C', ring: '#2A3035' }
};
const PAGE = { ink: '#111827', ink2: '#374151', muted: '#6B7280', faint: '#9CA3AF', quiet: '#D1D5DB', rule: '#F3F4F6', grid: '#F0F1F3', axis: '#D1D5DB', wash: '#F9FAFB', star: '#F59E0B', up: '#15803D', border: '#E5E7EB' };
// surface: 'page' | 'light' | 'dark'. The 7th project and later are gray.
function colorOf(pi, surface) {
  if (pi == null) return surface === 'page' ? PAGE.faint : THEMES[surface].faint;
  if (pi < 6) return PAL[surface === 'dark' ? 'dark' : 'light'][pi];
  return surface === 'page' ? PAGE.faint : THEMES[surface].faint;
}

function ms(s) { const p = s.split('-'); return Date.UTC(+p[0], +p[1] - 1, +p[2]); }
function iso(t) { return new Date(t).toISOString().slice(0, 10); }
function parts(t) { const d = new Date(t); return { y: d.getUTCFullYear(), m: d.getUTCMonth(), d: d.getUTCDate(), wd: (d.getUTCDay() + 6) % 7 }; }
function mStart(y, m) { return Date.UTC(y, m, 1); }
function weekNo(t) { const thu = t + (3 - parts(t).wd) * DAY; const j4 = Date.UTC(parts(thu).y, 0, 4); const w1 = j4 - parts(j4).wd * DAY; return 1 + Math.floor((thu - w1) / (7 * DAY)); }
function r1(v) { return Math.round(v * 10) / 10; }
function fmtDay(t) { const q = parts(t); return MON[q.m] + ' ' + q.d; }
function span(a, b) { const x = parts(a), y = parts(b); if (a === b) return fmtDay(a); return x.m === y.m ? MON[x.m] + ' ' + x.d + '–' + y.d : fmtDay(a) + ' – ' + fmtDay(b); }
function plural(n, w) { return n + ' ' + w + (n === 1 ? '' : 's'); }

const T0 = ms(TODAY);
const FIRST = Math.min(ms(Object.keys(DATA.days).sort()[0]), ...DATA.entries.map(e => ms(e.d)));

// Entries with the owner's tag choices applied: tags maps id to a project
// index, or -1 for "No project". Nothing is ever inferred from text.
function entriesWith(tags) {
  const t = tags || {};
  return DATA.entries.map(e => {
    const o = Object.assign({}, e);
    if (Object.prototype.hasOwnProperty.call(t, e.id)) { if (t[e.id] === -1) { delete o.r; o.none = true; } else o.r = t[e.id]; }
    return o;
  });
}

// Calendar periods: ISO week, calendar month, calendar year, all time.
function periodOf(range, offset) {
  const t = parts(T0);
  if (range === 'week') { const s = T0 - t.wd * DAY + offset * 7 * DAY; return { range, offset, start: s, end: s + 6 * DAY, unit: 'day' }; }
  if (range === 'month') { const s = mStart(t.y, t.m + offset); return { range, offset, start: s, end: mStart(t.y, t.m + offset + 1) - DAY, unit: 'day' }; }
  if (range === 'year') { const y = t.y + offset; return { range, offset, start: Date.UTC(y, 0, 1), end: Date.UTC(y, 11, 31), unit: 'week' }; }
  const f = parts(FIRST);
  return { range: 'all', offset: 0, start: mStart(f.y, f.m), end: mStart(t.y, t.m + 1) - DAY, unit: 'month' };
}
function running(p) { return p.start <= T0 && T0 <= p.end; }
function lastDay(p) { return Math.min(p.end, T0); }

// Counts for [s, e] (capped at today). proj: a project index, or null for all.
function tally(s, e, proj, ents) {
  const counts = DATA.projects.map(() => 0); const days = new Set(); let total = 0, all = 0; const end = Math.min(e, T0);
  Object.keys(DATA.days).forEach(k => {
    const t = ms(k); if (t < s || t > end) return; let hit = false;
    DATA.days[k].forEach(([pi, n]) => { all += n; if (proj != null && pi !== proj) return; counts[pi] += n; total += n; hit = true; });
    if (hit) days.add(k);
  });
  const hl = ents.filter(x => { const t = ms(x.d); return t >= s && t <= end && (proj == null || x.r === proj); });
  hl.forEach(x => days.add(x.d));
  return { counts, total, all, active: days.size, hl, shipped: hl.filter(x => x.k === 's').length, published: hl.filter(x => x.k === 'p').length, projects: counts.filter(n => n > 0).length };
}

// Buckets: a day each for Week and Month, an ISO week for Year, a month for All.
function bucketsOf(p, proj, ents) {
  const out = [];
  if (p.unit === 'day') { for (let s = p.start; s <= p.end; s += DAY) out.push({ s, e: s, mon: s }); }
  else if (p.unit === 'week') { for (let w = p.start - parts(p.start).wd * DAY; w <= p.end; w += 7 * DAY) out.push({ s: Math.max(w, p.start), e: Math.min(w + 6 * DAY, p.end), mon: w }); }
  else { let s = p.start; while (s <= p.end) { const q = parts(s); const e = mStart(q.y, q.m + 1) - DAY; out.push({ s, e, mon: s }); s = e + DAY; } }
  return out.map((b, i) => Object.assign(b, tally(b.s, b.e, proj, ents), { i, future: b.s > T0, today: b.s <= T0 && T0 <= b.e }));
}
// One label per bucket, or '' where the axis stays quiet.
function axisLabel(p, bs, i) {
  const b = bs[i]; const q = parts(b.s);
  if (p.range === 'week') return WD[q.wd] + ' ' + q.d;
  if (p.range === 'month') return [1, 8, 15, 22, 29].indexOf(q.d) >= 0 ? (q.d === 1 ? MON[q.m] + ' 1' : String(q.d)) : (b.today ? String(q.d) : '');
  if (p.range === 'year') { const m = parts(b.mon + 3 * DAY).m; return (i === 0 || m !== parts(bs[i - 1].mon + 3 * DAY).m) ? MON[m] : ''; }
  return MON[q.m] + (i === 0 || q.m === 0 ? ' ' + q.y : '');
}
// The bucket title for tooltips.
function bucketTitle(p, b) {
  const q = parts(b.s);
  if (p.unit === 'day') return WD[q.wd] + ', ' + MON[q.m] + ' ' + q.d;
  if (p.unit === 'week') return 'Week of ' + span(b.s, b.e);
  return MONTH[q.m] + ' ' + q.y;
}

function namesOf(p, proj) {
  const run = running(p); const q = parts(p.start); const last = lastDay(p);
  const project = proj == null ? null : DATA.projects[proj];
  let n;
  if (p.range === 'week') { const w = weekNo(p.start); n = { title: 'Week ' + w, sub: span(p.start, p.end) + ', ' + parts(p.end).y + (run ? ' · so far' : ''), nav: 'Week ' + w + ' · ' + span(p.start, p.end), tag: 'PROGRESS · WEEK', word: run ? 'this week' : 'in Week ' + w, short: 'Week ' + w, file: parts(p.start + 3 * DAY).y + '-w' + String(w).padStart(2, '0') }; }
  else if (p.range === 'month') n = { title: MONTH[q.m] + ' ' + q.y, sub: run ? span(p.start, last) + ' · so far' : span(p.start, p.end), nav: MONTH[q.m] + ' ' + q.y, tag: 'PROGRESS · MONTH', word: 'in ' + MONTH[q.m], short: MONTH[q.m], file: q.y + '-' + String(q.m + 1).padStart(2, '0') };
  else if (p.range === 'year') n = { title: String(q.y), sub: run ? 'Jan 1 – ' + fmtDay(last) + ' · so far' : 'Jan 1 – Dec 31', nav: String(q.y), tag: 'PROGRESS · YEAR', word: 'in ' + q.y, short: String(q.y), file: String(q.y) };
  else { const f = parts(FIRST); n = { title: 'All time', sub: 'Since ' + MONTH[f.m] + ' ' + f.y, nav: 'Since ' + MON[f.m] + ' ' + f.y, tag: 'PROGRESS · ALL TIME', word: 'so far', short: 'All time', file: 'all-time' }; }
  return Object.assign(n, { running: run, project, empty: 'Nothing shipped or published ' + n.word + (run && p.range !== 'all' ? ' yet' : '') + '.', emptyTagged: project ? 'No entries tagged ' + project + ' ' + (p.range === 'all' ? 'yet' : n.word) + '.' : '' });
}

function summaryOf(p, proj, ents) {
  const cur = tally(p.start, p.end, proj, ents); let prev = null, vs = '';
  if (p.range !== 'all') {
    const q = periodOf(p.range, p.offset - 1); const run = running(p);
    const qEnd = run ? Math.min(q.end, q.start + (T0 - p.start)) : q.end;
    if (q.end >= FIRST) {
      prev = tally(q.start, qEnd, proj, ents);
      if (p.range === 'week') vs = run ? 'vs Mon–' + WD[parts(T0).wd] + ' last week' : 'vs Week ' + weekNo(q.start);
      else if (p.range === 'month') vs = run ? 'vs ' + span(q.start, qEnd) : 'vs ' + MONTH[parts(q.start).m];
      else vs = run ? 'vs ' + parts(q.start).y + ' to ' + fmtDay(qEnd) : 'vs ' + parts(q.start).y;
    }
  }
  return { cur, prev, vs, share: cur.all ? Math.round(100 * cur.total / cur.all) : 0 };
}
function deltaOf(c, p) { if (p == null) return null; const d = c - p; return { text: d > 0 ? '+' + d : d < 0 ? '−' + Math.abs(d) : '±0', up: d > 0 }; }

// Entries in the period with no project that the owner has not marked "No project".
function untaggedOf(p, ents) { const end = lastDay(p); return ents.filter(x => { const t = ms(x.d); return t >= p.start && t <= end && x.r == null && !x.none; }); }

// The shared pick: who gets words. It never reads the text.
// 1. Pins first, always kept. 2. Six equal day spans over the active domain.
// 3. Shipped in rounds, one per span per round (a span holding a pin skips
// round 1), newer first within a round. 4. Published the same way while room
// is left (round 1 skips spans already holding an entry). 5. Display in date
// order. feature: ids the owner swapped in on the card; each replaces the
// lowest-ranked unpinned entry.
function pick(p, proj, cap, ents, feature) {
  const end = lastDay(p);
  const pool = ents.filter(x => { const t = ms(x.d); return t >= p.start && t <= end && (proj == null || x.r === proj); });
  if (!pool.length) return { kept: [], left: [], ids: new Set() };
  let first = Infinity;
  Object.keys(DATA.days).forEach(k => { const t = ms(k); if (t < p.start || t > end) return; if (proj == null || DATA.days[k].some(c => c[0] === proj)) first = Math.min(first, t); });
  pool.forEach(x => { first = Math.min(first, ms(x.d)); });
  const days = Math.round((end - first) / DAY) + 1;
  const spanOf = x => Math.min(5, Math.floor(6 * Math.round((ms(x.d) - first) / DAY) / days));
  const newest = (a, b) => (a.d < b.d ? 1 : a.d > b.d ? -1 : b.id - a.id);
  const ranked = pool.filter(x => x.pin).sort(newest).slice(0, Math.max(cap, 0));
  const held = new Set(ranked.map(spanOf));
  ['s', 'p'].forEach(kind => {
    const lanes = [0, 1, 2, 3, 4, 5].map(s => pool.filter(x => !x.pin && x.k === kind && spanOf(x) === s).sort(newest));
    const at = [0, 0, 0, 0, 0, 0];
    for (let round = 0; ranked.length < cap; round++) {
      const batch = [];
      for (let s = 0; s < 6; s++) { if (round === 0 && held.has(s)) continue; if (at[s] < lanes[s].length) batch.push(lanes[s][at[s]++]); }
      if (!batch.length && lanes.every((l, s) => at[s] >= l.length)) break;
      batch.sort(newest).forEach(x => { if (ranked.length < cap) { ranked.push(x); held.add(spanOf(x)); } });
    }
  });
  // A swap never pushes out a pin or an earlier swap.
  const swapped = new Set();
  (feature || []).forEach(id => {
    if (ranked.some(x => x.id === id)) return;
    const f = pool.find(x => x.id === id); if (!f) return;
    for (let i = ranked.length - 1; i >= 0; i--) { if (!ranked[i].pin && !swapped.has(ranked[i].id)) { ranked.splice(i, 1); break; } }
    if (ranked.length < cap) { ranked.push(f); swapped.add(f.id); }
  });
  const ids = new Set(ranked.map(x => x.id));
  const byDate = (a, b) => (a.d < b.d ? -1 : a.d > b.d ? 1 : a.id - b.id);
  return { kept: ranked.slice().sort(byDate), left: pool.filter(x => !ids.has(x.id)).sort(byDate), ids, rank: ranked };
}

// Projects for the filter: commits or tagged entries, in all-time order.
function projectOptions(ents) {
  const totals = DATA.projects.map(() => 0);
  Object.values(DATA.days).forEach(list => list.forEach(([pi, n]) => { totals[pi] += n; }));
  return DATA.projects.map((slug, pi) => ({ pi, slug, n: totals[pi], label: slug + ' · ' + totals[pi] })).filter(o => o.n > 0 || ents.some(x => x.r === o.pi));
}
// Commits per project on one day, busiest first (orders the tag buttons).
function commitsOn(day) { return (DATA.days[day] || []).map(([pi, n]) => ({ pi, n })).sort((a, b) => b.n - a.n); }

// ----- Card text: the server measures with these Inter tables (thousandths
// of an em, ASCII 0x20-0x7E plus a few marks). DM Mono is 600 per character.
const INTER = {"400":{"base":[282,288,466,634,642,982,645,300,365,365,501,662,289,460,289,361,631,407,610,618,646,594,621,566,619,621,289,302,662,662,662,512,966,690,655,731,722,602,591,747,744,269,571,672,566,904,754,765,639,765,644,642,646,745,690,986,683,679,629,365,361,365,472,457,323,562,613,572,613,584,371,614,592,243,243,549,243,876,591,600,613,613,377,528,328,592,563,819,546,563,553,427,333,427,662],"extra":{"·":289,"–":500,"—":1000,"‘":261,"’":261,"“":441,"”":441,"…":865,"•":563,"×":662}},"500":{"base":[267,305,495,639,646,994,654,313,369,369,521,668,304,463,304,370,646,415,617,627,657,603,630,572,630,630,304,316,668,668,668,528,983,709,657,734,722,604,590,748,745,273,576,688,566,913,757,767,642,769,648,646,653,741,709,1003,701,697,641,369,370,369,477,463,337,568,619,577,619,588,380,620,602,252,252,560,252,889,602,605,619,619,387,539,341,602,575,829,558,576,560,441,346,441,668],"extra":{"·":304,"–":500,"—":1000,"‘":278,"’":278,"“":474,"”":471,"…":911,"•":534,"×":668}},"600":{"base":[252,322,523,644,651,1005,663,326,373,373,540,674,319,466,319,379,660,424,623,637,667,613,640,577,641,640,319,330,674,674,674,544,1000,728,660,737,723,606,589,750,746,277,580,704,566,923,760,769,645,773,653,651,661,737,728,1021,720,714,653,373,379,373,482,470,352,575,625,583,625,592,389,626,613,262,262,570,262,901,612,609,625,625,397,550,354,613,588,840,569,589,566,455,359,455,674],"extra":{"·":319,"–":500,"—":1000,"‘":294,"’":294,"“":507,"”":502,"…":957,"•":504,"×":674}}};
// The card strips emoji, as the week cards do; 𝕏 is a letter and stays.
function stripEmoji(s) { return s.replace(/\p{Extended_Pictographic}/gu, '').replace(/[︎️‍]/g, '').replace(/\s{2,}/g, ' ').trim(); }
function charW(ch, weight) {
  const c = ch.codePointAt(0); const t = INTER[String(weight)] || INTER['400'];
  if (c >= 0x20 && c <= 0x7E) return t.base[c - 0x20];
  if (t.extra[ch] != null) return t.extra[ch];
  return c === 0x1D54F ? 1020 : 600;
}
// Width in px of Inter text at size px; ls is letter-spacing in em.
function measure(s, weight, size, ls) { let w = 0, n = 0; for (const ch of s) { w += charW(ch, weight); n++; } return w / 1000 * size + (ls || 0) * size * n; }
function monoW(s, size, ls) { return Array.from(s).length * size * (0.6 + (ls || 0)); }

// A title ending in ":" continues into its own body: bullets stripped, empty
// lines and lines equal to the title or a project slug dropped, joined by " · ".
function runInOf(x) {
  const t = x.t.trim(); if (!t.endsWith(':') || !x.b) return '';
  return x.b.split('\n').map(l => l.replace(/^\s*[-*•]\s*/, '').trim()).filter(l => l && l !== t && DATA.projects.indexOf(l) < 0).join(' · ');
}

// Balanced wrapping: the fewest lines that fit, then the narrowest measure
// that keeps that count. Past maxLines, cut at a word with "…" (never
// mid-word, unless a single word is wider than the measure).
function wrapText(text, weight, size, width, maxLines, ls) {
  // A lone dash never starts a line: it stays with the word before it.
  const words = text.split(/\s+/).filter(Boolean).reduce((acc, w) => { if (/^[—–-]$/.test(w) && acc.length) acc[acc.length - 1] += ' ' + w; else acc.push(w); return acc; }, []);
  const W = s => measure(s, weight, size, ls);
  // Lines as arrays of tokens, so a cut knows exactly which words it used.
  const greedy = lim => { const out = []; let cur = []; words.forEach(w => { const t = cur.concat(w).join(' '); if (!cur.length || W(t) <= lim) cur.push(w); else { out.push(cur); cur = [w]; } }); if (cur.length) out.push(cur); return out; };
  let rows = greedy(width);
  if (rows.length <= maxLines) {
    if (rows.length > 1) {
      let lo = Math.max(...words.map(W)), hi = width; const n = rows.length;
      for (let k = 0; k < 14; k++) { const mid = (lo + hi) / 2; if (greedy(mid).length <= n) hi = mid; else lo = mid; }
      rows = greedy(hi);
    }
    const lines = rows.map(r => r.join(' '));
    return { lines, cut: false, widths: lines.map(W) };
  }
  const keep = rows.slice(0, maxLines - 1).map(r => r.join(' '));
  const used = rows.slice(0, maxLines - 1).reduce((n, r) => n + r.length, 0);
  let last = '';
  for (const w of words.slice(used)) { const t = last ? last + ' ' + w : w; if (W(t + '…') <= width) last = t; else break; }
  if (!last) { const chars = Array.from(words[used] || ''); while (chars.length && W(chars.join('') + '…') > width) chars.pop(); last = chars.join(''); }
  keep.push(last.replace(/[\s,;:·–—.\-]+$/, '') + '…');
  return { lines: keep, cut: true, widths: keep.map(W) };
}
// The run-in only fills what is left of the title's last line, cut at a word
// with "…"; it is dropped when fewer than 6 characters fit.
function fitRunIn(runIn, room, weight, size, ls) {
  if (!runIn || room <= 0) return '';
  if (measure(runIn, weight, size, ls) <= room) return runIn;
  let out = '';
  for (const w of runIn.split(/\s+/)) { const t = out ? out + ' ' + w : w; if (measure(t + '…', weight, size, ls) <= room) out = t; else break; }
  out = out.replace(/[\s,;:·–—.\-]+$/, '');
  return Array.from(out).length >= 6 ? out + '…' : '';
}
// ===== end of shared core =====
