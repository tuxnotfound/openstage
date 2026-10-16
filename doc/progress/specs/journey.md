# Option: Journey line (key: journey)

Why it made the cut: The bold option. One cumulative commits line per range, with his entries standing on it as flags. It is the annotated-MRR chart builders already share on X, and under a project filter it becomes that project's story line. It is the most distinct image of the three and already renders on real data. Grafts: the shared pick as the flag priority. An ink line in every view, with project color only in the wash, which fixes the contrast fail of yellow and gray lines. The shared tag panel instead of bulk select-all.

## Page spec
CHART BOX: 704x248 (unchanged size), aspect-ratio 704/248, fluid. The marker row, label lanes and leaders are gone, and so are the stacked bars.
- Plot x30-698. Top tick at y22, baseline y220. Flags may use y4-216.
- Axes: tick labels Inter 400 10px #9CA3AF, right-aligned at x22. Hairline grid #F0F1F3 at round values (October: 0/50/100/150). Baseline 1px #D1D5DB.
- X labels: Inter 400 11px #9CA3AF, baseline y237. Today: Inter 600 #111827. Future: #D1D5DB.
- y = commits since the period start, so the line ends at the Commits KPI. Vertices: daily in Week and Month, weekly in Year and All. The line stops at today; the rest of the period stays empty.
- Line: 2px #111827, round joins.
- Wash: a gradient under the line, #111827 from 10% at the top to 2% at the baseline. Under a filter it uses the project color, 22% to 4%.
- Markers sit on the line at their bucket: shipped a 12x12 diamond, ink; published a ring r4.6 with a 2px ink stroke and white fill. 2px white halo. One marker per bucket: a diamond if any entry there shipped. The bucket is a day in Week/Month and an ISO week in Year/All (a month below 12px per week).
- End dot r4, ink. End label: "150" Inter 600 13px #111827 plus " commits" Inter 400 13px #6B7280, 10px right of the end dot, or above-left when there is no room.
- Flags: Inter 13px on a 16px line, measure 180px, 1 or 2 lines. Pinned: 600 #111827. Shipped: 500 #111827. Published: 400 #6B7280.
  - Each flag sits 7px beside a 1px #C9CDD3 pole that rises from the marker halo. Pole gaps: 6, 22, 38 or 54px.
  - The chart uses the self-hosted inter.woff2 (font-display: block) so server widths match.
- Placement is computed on the server, shared with the card (CardLayout::Journey::Flags). A flag must:
  - stay inside the plot;
  - sit 3px clear above the line across its width;
  - keep 6px from other flags, poles and markers;
  - keep 40px sideways and 8px vertically from the end label;
  - never have its pole cross another flag.
  Left-of-marker is tried first on a rising line.
- Under the chart, one 12px mix line: "● openstage 76 · ● wheels-off 47 · …". Each name sets ?repo=. A "Show as table" disclosure lists each bucket's commits by project.
- Below 560px a second SVG renders: viewBox 360x240, plot x26-354, baseline y212, flags 12.5px/15px, measure 150, caps 2/2/3/3.

REAL DATA (page)
- October: vertices 1,2,2,2,2,8,27,35,42,42,71,78,142,150,150.
  - Diamond Oct 1 at (40.8,219.3), flag "Trained on me is live!!" box 48-186 x157-173.
  - Ring Oct 9 at (213.2,169.2), flag "What I worked on this week: / 40 commits across 3 repos." box 32-206 x108-140.
  - The Oct 2 ring is bare (no room).
  - End label "150 commits" at 363,14.
- Week 42: Mon 7, Tue 71, Wed 79, Thu 79; end label "79 commits"; no markers.
- Year: 10 markers. Page cap 5: Trained on, Rebirth, Share on 𝕏 !, Goal Atlas, We are live!!.
- Renders: scratchpad/journey/page_month0.png, page_year0.png.

## Card spec
Header and title block unchanged. Tag line y166, title y184, subtitle y244 Inter 400 16px muted. Under a filter the subtitle reads "● trained-on · Jan 1 – Oct 15 · so far" (12px project dot, slug in ink 500).

STATS ROW, right of the title, columns at x672, 790, 908 and 1026, in this order: ◆ SHIPPED, ○ PUBLISHED, COMMITS, ACTIVE DAYS.
- Value: Inter 600 30px, baseline 214.
- Change: DM Mono 500 12px right after the value, accent when up, faint otherwise.
- Label: DM Mono 500 11px, .1em, baseline 236, with a 10px diamond or 8px ring glyph. These are the marker key.

CHART: plot x100-1140, top tick y318, baseline y552. Flags may use y282-548.
- Ticks: DM Mono 400 11px faint, right-aligned at x88. Grid 1px rule; baseline 1px ruleStrong.
- X labels: DM Mono 500 11px, uppercase, .08em, baseline 578. Today in ink, the rest faint.
- Domain: from one unit before the first activity (a day in Week/Month, a month in Year/All), or the period start if later. A running period stops at today (Week, Month) or at the end of the current month (Year, All). Year 2026 runs Feb 1-Oct 31.
- Line: 2.5px ink. Wash: ink 10% to 2%, or the project color 22% to 4% under a filter.
- Markers: a 16x16 diamond; a ring r6.2 with a 2.6px stroke and bg fill; 3px bg halo. End dot r5.
- End label: "380" Inter 600 24px ink plus " commits" Inter 400 17px muted.
- Flags: Inter 20px on a 24px line, measure 290px, 1-2 lines. Pinned 600 ink, shipped 500 ink, published 400 muted.
  - Pole 1px, #BDBBB1 light / #4A5258 dark. Text sits 10px from the pole. Pole gaps 8/28/48/68px.
  - The same constraints as the page, with 72px sideways clearance from the end label.
- No project legend: the line is one series.
- Empty (no entries): the line, the end label, and at the plot's top-left, Inter 500 20px muted: "Nothing shipped or published this week yet." Under a filter: "No entries tagged trained-on in 2026 yet."

REAL DATA (Year 2026, light, measured)
- Flag boxes:
  - "We are live!!" 175-294 x505-529
  - "Share on 𝕏 !" 331-453 x478-502
  - "launched The Goal Atlas — / just in time for 2026" 354-587 x420-468
  - "Rebirth begins" 794-934 x414-438
  - "Trained on me is live!!" 802-1014 x383-407
  - "What I worked on this week: / 40 commits across 3 repos." 773-1041 x330-378
- End dot at 1079,330; end label 955-1075 x288-318.
- Renders: scratchpad/journey/card_year0_light.png, card_year0_dark.png, card_month0_light.png, card_week-2_light.png, card_year0_trained_light.png.

## Events rule
Markers: one per bucket with entries (diamond if any shipped, else ring). 20 entries in 2026 give 10 markers.
Flags: at most one per bucket. A bucket's flag carries its first entry in the shared pick order (pins, then the shipped span rounds, then posts).
- Buckets are tried in that order until the cap: page 3/3/5/5, mobile 2/2/3/3, card 3/4/6/6 (Week/Month/Year/All).
- A bucket that fits nowhere stays a bare marker, and the next one is tried.
- On the Year card, live on Hacker News (W14) and Pro tier shipped (W18) fit nowhere. So the flags are We are live!!, Share on 𝕏 !, Goal Atlas, Rebirth, Trained on, and the Oct 9 post.
Titles: 1 line if it fits the measure. Two balanced lines (phrases rule: break after punctuation, never start a line with a dash) only when wider than 60% of the measure. Past 2 lines, a word cut with "…".
Emoji are stripped on both chart surfaces (page and card); the tooltip, list and draft keep them. 𝕏 is kept.
The list below the chart keeps every entry, newest first as today, with ◆/○.

## Project filter
Shared filter rules apply.
- The line becomes that project's cumulative commits. The domain refits to its first activity. The line stays ink, and the wash takes the project color. Markers and flags come from tagged entries only.

Today's tags
- trained-on 2026: the chart runs Aug-Oct and climbs 0→31 from late September. One diamond, Oct 1, with the pinned flag "Trained on me is live!!".
- openstage 2026: a line 0→176 with no markers. Visitors see the list's "No entries tagged openstage in 2026."
- The owner gets the untagged line above the list and the shared panel.

After tagging, openstage's line carries its launches in March, Pro and Share on 𝕏 in April-May, and Rebirth in September, placed by the same flag rules.

## Interaction
- Hover or focus the plot: a crosshair snaps to the bucket (a 1px #D1D5DB hairline at the bucket's end vertex and a 6px ring on the line).
  - The dark 220px tooltip leads with the bucket value, "+64 commits", then "71 so far this week".
  - Then per-project rows (dot + slug + count), then that bucket's entries (mark, full title with emoji, ★, project chip). At most 4, then "+N more in the list".
- Markers are buttons: tabindex 0, a 24px hit target, aria-label "Shipped, Oct 1: Trained on me is live!! (pinned)". Tab walks markers in date order. ←/→ move the crosshair. Esc hides the tooltip.
- Click a marker or its flag: that bucket's rows in the list get #F3F4F6 for 1.5s and scroll into view. Hovering a list row rings its marker and darkens its flag.
- Touch: a tap acts as hover; a tap outside closes.
- Chart aria-label: "Commits so far in October 2026: 150; 1 shipped and 2 published entries".
- Owner: the untagged line, the panel, and Make a card with the shared modal.

## Known risks (from the design round)
- The shape is the commit total going up, close to the 'number as hero' Swiss Report he rejected. The flags are the largest text, but volume drives the image.
- It drops the project-colored stacked bars everywhere. Project mix moves to the tooltip, the mix line and the table.
- A 64-commit day reads as a ramp, not a spike. Week has only 4 points.
- Poles are leader lines. If leaders were part of what he disliked, this keeps them, though shorter and tied to the data.
- Flag placement is the hardest engine of the three. It also needs two page SVGs (704 and 360) and a crosshair controller of about 120 lines.
- The card axis stops at today or this month, while the page shows the whole period.
- Ranked entries can find no room (Year: live on Hacker News, Pro tier shipped). Only Swap in steers the card.

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
