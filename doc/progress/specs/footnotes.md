# Option: Footnotes (key: footnotes)

Why it made the cut: The chart keeps its full height and gets words without any text on the plot. Numbered discs ride the bars, and the same numbers start each note in a list, so chart and words read in one time order. It ranked second with the builder and data-viz judges. Grafts: the shared pick, cap 6; one disc per bucket, with a range pill like "2–3" instead of stacking, so the plot never jumps; a fixed headroom band; an empty-period line instead of dropping the notes column; the colon run-in cut to the title's lines.

## Page spec
CHART BOX: 704x220, fluid, aspect-ratio 704/220. viewBox units equal px at 704.
- Disc headroom y0-34. Top tick fixed at y34, baseline y196. X labels: 11px, top y205.
- Plot x30-698, slot = 668/n.
- Y ticks at nice values with 1px #F0F1F3 gridlines. Labels 10px #9CA3AF, right-aligned at x24.
- Bars as today: stacked, 24px max, 2px gaps, 4px round tops.
- Removed: label lanes, leaders, marker row.

DISCS: one per bucket that holds noted entries.
- A single note gets a 16px circle. Several notes in one bucket get one pill, 26x16, radius 8, showing "2–3" (first and last number).
- Filled #111827 with a white numeral when any noted entry in the bucket shipped. Otherwise white fill with a 1.5px #111827 ring and an ink numeral.
- Numerals: system-ui 600 10px, tabular. 2px white halo. Hit circle 24px.
- Center x = the bucket center. Center y = bar top - 3 - 8, or y185 for a 0-commit bucket.
- Collision sweep, left to right: x = max(own x, previous x + (previous width + own width)/2 + 2). If the last disc passes x690, sweep back from the right the same way. Discs never stack vertically, so the top tick never moves.
- Discs live in a top SVG layer above the bar hit columns.
- Below a 600px column the numerals hide and discs become 8px dots. The list keeps the numbers.

LEGEND ROW: unchanged, swatch + project + count. The key moves to the list header.

NOTES LIST (ol), 20px under the legend
- Header: "Shipped and published in October 2026", 11px 600 uppercase #9CA3AF. Right-aligned key: filled disc "shipped", hollow disc "published".
- Rows: 8px vertical padding, 1px #F3F4F6 top border. A 16px disc with the note's number at x0, 2px below the row top.
- Text at x28. Title: 14px/20px 500 #111827, wrapped whole. Run-in: 400 #6B7280, capped server-side at 160 characters on a word boundary with "…".
- Right meta: project chip when tagged (All projects only), ★ #F59E0B when pinned, date 12px #9CA3AF tabular.
- Rest row: "14 more in 2026 ▾", 12px #6B7280. Opened, it lists the others in date order with a 10px ◆/○ (no number) at x3.
- Empty: the shared empty line in the list.

REAL DATA (page)
- October: [1] Oct 1 at (40.8,182.7); (2) Oct 2 at (62.3,182.7); (3) Oct 9 above its 7-commit bar.
- Year: 1 on W14; pill [2–3] on W19 (55 commits); 4 on W24; 5 on W37; 6 on W40.
- All: 1 on Mar, [2–3] on May, 4 Jun, 5 Sep, 6 Oct (the 150 bar).
- Week 42: no discs.
- Week 13: 6 notes; Thu 26 and Sat 28 show pills [2–3] and [4–5].

## Card spec
Header unchanged; rule at y136. A vertical 1px rule at x650, y166-580 (rule color).

LEFT COLUMN x60-620
- Tag line at y166, title at y184 (Inter 600 46px).
- Dateline at y244, Inter 400 16px muted: "Jan 1 – Oct 15, so far · 380 commits on 64 days". Under a filter it starts with "● openstage · " (10px project dot, slug in ink 500).
- Chart: plot x96-620 (524px). Top tick fixed at y318, baseline y528. Gridlines 1px rule. Y labels DM Mono 400 11px faint, right edge x88. X labels DM Mono 500 11px caps, .08em, top y536: faint, current unit in ink, future in ruleStrong.
- Bars: 0.62 x slot, at most 24px, 2px bg gaps, 4px tops.
- Discs: 20px, or pills 32x20 radius 10. Inter 600 12px numeral, 4px above the bar top, 2px bg halo. Shipped: ink fill, bg numeral. Published: bg fill, 1.75px ink ring, ink numeral. The page's collision sweep with a 2px gap.
- Legend at y562: 11px swatch, Inter 500 13px name, DM Mono 400 12px count, 22px gaps. As many items as fit in 560px, then "+N more". Hidden under a filter.

RIGHT COLUMN x680-1140
- Header at y166, DM Mono 500 12px, .14em, muted: "● 10 SHIPPED   ○ 10 PUBLISHED" with 10px filled and hollow disc glyphs. A kind with 0 is left out.
- Notes y196-548 (352px). A 20px numbered disc at x680-700, centered on the first line. Text x716-1140 (424px).
- Title: Inter 500 ink. Run-in: Inter 400 muted (shared rule).
- Size steps 32/28/24/20, line height 1.25 x size, gap 0.5 x size, at most 3 balanced lines, then a word cut with "…". The largest size where all notes fit wins. If 6 do not fit at 20px, drop the lowest-ranked unpinned note.
- Footer at y560, Inter 400 14px muted: "+14 more at openstage.dev/tuxnotfound". Hidden at 0.
- Empty: at y196, Inter 500 24px muted, wrapped in 424px: "Nothing shipped or published this week yet." Under a filter with no tagged entries: "No entries tagged openstage in 2026 yet."

REAL DATA
- Year at 28px:
  1 live on Hacker News
  2 story time is live!
  3 Share on 𝕏 !
  4 launched The Goal Atlas — / just in time for 2026
  5 Rebirth begins★
  6 Trained on me is live!!★
  Chart: disc 1 on W14, pill 2–3 on W19, 4 on W24, 5 on W37, 6 on W40. Year bars are 6.1px on 9.9px slots.
- October at 32px: 3 notes, the build-log note with its run-in.
- September at 20px: 5 notes; the two long posts end in "…" after 3 lines.
- Week 42: empty line.

## Events rule
Words: the shared pick, cap 6 on page and card. Numbers run 1-6 in date order (1 = earliest), so they stay single-digit.
Chart: one disc or pill per bucket holding noted entries; un-noted entries get no chart mark. They are in the rest row, the tooltip and the card footer count.
No text on the chart in any range.
Fitting: the card notes column steps 32/28/24/20 with at most 3 balanced lines and a word cut. The page wraps titles whole (the run-in is capped at 160 characters).
Emoji are stripped on the card and kept on the page.
Numbers belong to the view: note 3 in Year is not note 3 in May.

## Project filter
Shared filter rules apply.
- Bars become single-series. The pick and the numbering re-run on tagged entries. The notes header reads "Shipped and published in 2026 · openstage".

Today's tags
- trained-on 2026: one note, [1] Trained on me is live!!★, on W40. The card sets it at 32px.
- openstage 2026: no discs. The card right column shows "No entries tagged openstage in 2026 yet."
- The owner sees the untagged line under the notes and the shared panel.

After tagging (sample choices), openstage 2026 at cap 6: 1 We are live!!, 2 live on Hacker News, 3 Pro tier shipped, 4 First user signed up, 5 Share on 𝕏 !, 6 Rebirth begins★. Discs on W13, W14, W18, and a pill [4–5] on W19, then W37.

## Interaction
- Hover or focus a disc: a 2px ring on the disc and the hover wash on its bar. The bar tooltip opens as today; its entry lines lead with their disc, the hovered one in bold. The matching list row gets a #F3F4F6 wash.
- Hover or focus a list row: its disc and bar light up the same way. No tooltip.
- Click or Enter on a disc: focus jumps to its row (#note-3), which scrolls into view and flashes for 1s. A pill jumps to its first row.
- Click a row: it opens the entry in the timeline below via the existing #entry anchor highlight.
- Bars keep their per-bucket hit columns and tooltip. Un-noted entries appear in the tooltip with a "·".
- Keyboard: discs are SVG links with aria-labels such as "Note 3, shipped May 8: Share on 𝕏 !". Tab order: range tabs, project select, arrows, Make a card, discs, rows.
- Touch: tap a bar for its tooltip; tap a disc to jump to its row.
- Owner: the untagged line and the panel; Make a card with the shared modal.

## Known risks (from the design round)
- The card chart shrinks from 800 to 524px. Year bars are 6px and can look thin at 500px in the feed.
- Matching numbers between chart and notes is eye ping-pong; feeds punish that.
- Card type size swings from 32 to 20px across cards.
- The card notes carry no dates; disc position is the only time cue there.
- Range pills ([2–3]) are a small new idea to read.
- No real render exists yet; every number comes from a probe (scratchpad/fn). Build the card first and check it.
- On phones the numerals hide, so the chart-to-list link rests on order and taps.
- The empty-period card is chart-heavy, close to the Swiss Report he rejected.

## Shared rules (every option)
PICK (who gets words; never reads the text). Used by every option, page and card, with a per-option cap.
1. Pinned entries in range, newest first. They are always kept.
2. Domain = first day in range with a commit or entry (of the selected project under a filter) through min(period end, today). Cut it into 6 equal day spans: span = floor(6 x (day - first) / days), capped at 5.
3. Shipped pass: in round 1 each span gives its best unpinned shipped entry (newest first). A span that already holds a pin skips round 1. Round 2 gives each span's next one, and so on. Within a round, newer entries go first. Stop at the cap.
4. Published pass: the same rounds over posts, only while room is left.
5. Show the kept entries in date order, oldest first. Display order never depends on rank.
Real data, cap 8: Year and All = We are live!!, live on Hacker News, First user signed up, story time is live!, Share on 𝕏 !, launched The Goal Atlas, Rebirth begins★, Trained on me is live!!★. Left out: 2 shipped (day 1, Pro tier) and 10 published. Cap 6: live on Hacker News, story time is live!, Share on 𝕏 !, Goal Atlas, Rebirth★, Trained on★. October: all 3. September: all 5. March, cap 6: 6 of 7 (on picking rails drops). Week 42: 0.

TEXT RULES
- The page keeps emoji. The card strips them with CardText.clean, the week-card rule. 𝕏 is a letter: keep it, measure it at CardText::WIDE (1.02em), draw it with the fallback font. Never split a grapheme.
- On the card, titles wrap with CardLayout::Lines#balance. They are cut at a word with "…", never mid-word.
- Colon run-in. A title that ends in ":" continues into its own body, in muted ink. Body cleanup: strip bullet markers, drop empty lines, drop lines equal to the title or to a project slug, join the rest with " · ".
- The run-in never adds a line on the card. It only fills the rest of the lines the title already uses, then ends in "…". Drop it when fewer than 6 characters fit.
- Results: "This week's build log: Trained on me is live!! · UI cleanup · Landing page…" and "Shipped this week: A new feature in OpenStage to help me recap my week's work…".

COLORS
- A project's color is fixed by all-time commits: #2a78d6, #eb6834, #1baf7a, #eda100, #e87ba4, #008300. The 7th project and later are gray: #9CA3AF on the page, the faint token on the card.
- Text is never in a series color. Project identity is an 8px dot (r3.5 on the card) beside ink text.
- Event marks are always ink: shipped is a filled shape, published a hollow one.

KPI ROW (page): Shipped, Published, Commits, Active days, Projects. The Shipped and Published labels carry their option's glyph, so they double as the key. Deltas stay. The plot height is fixed in every option, so bars never rescale between empty and busy periods.

PROJECT FILTER UI
- A native select sits between the range tabs and the period arrows.
- Options: "All projects", then every project with commits or tagged entries, in all-time order, labeled "openstage · 176" with a 10px swatch.
- It reuses the timeline's existing ?repo= param, so one control scopes the progress section and the timeline below it. The card and the post draft follow it.
- Filtered:
  - Bars become one series in the project's color, with the y-scale refit. The legend hides.
  - KPIs recount. Commits = its commits. Active days = its commit days plus days with its tagged entries. The Projects tile becomes "Share of commits" (openstage: 46% of 2026, 51% of October). Shipped and Published count its tagged entries.
  - Events = entries tagged with that project only. The pick re-runs on that subset.

UNTAGGED
- Untagged entries never appear in a project view, and nothing is inferred from text or dates.
- Visitors see "No entries tagged openstage in 2026."
- Owner, in every view, when the range has untagged entries not marked No project: a 12px #6B7280 line, "19 entries in 2026 have no project. Tag them". Under a filter it adds ", so this view leaves them out".
- "Tag them" opens an inline panel under the list (a Turbo Frame, not a modal). Rows are newest first: glyph, date, full title.
- Buttons, in order: the selected project (when filtered); projects with commits that day, by count ("story_time_v1 · 19 that day"); "Other ▾"; "No project".
- Nothing is preselected. One click saves that row with a Turbo PATCH. The row leaves and the section redraws.
- Keys: ↑/↓ move between rows, 1 picks the first button, 0 picks No project. The panel shows 6 rows, then "Show 13 more".
- Migration: entries.no_project boolean, default false. Cross-repo weekly logs marked No project leave the untagged count for good.
- EntriesController#update gets a branch that sets only repo_name/no_project for any entry type. Today it edits manual entries only, so synced posts could not be tagged. Add owner-scope and CSRF request specs.
- About 19 clicks fix Tux's backlog. Do it before Tue 2026-10-20.

EMPTY PERIODS: the page says "Nothing shipped or published this week yet." (month, year…), plus "Log an entry" for the owner. Each card option has its own empty layout, below.

MAKE A CARD MODAL
- A "Not on the card" list: entries the pick left out, each with "Swap in".
- Swap in is card-only. It goes into the card URL as &feature=<ids>, swaps out the lowest-ranked unpinned kept entry, and re-fits. It needs no pin: pins are Pro-only, capped at 3, and Tux already has 2.
- Under a filter with untagged entries, it warns: "19 entries in 2026 have no project and are not on this card. Tag them".
- The post draft lists the card's entries in date order, verbatim with emoji, then one line: "380 commits on 64 days."

PREREQUISITE: CardText, CardLayout::Lines/Canvas/Shapes and inter.woff2 live only on recap-card. Merge it Friday morning, before any progress work.
