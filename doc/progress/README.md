# Progress page design references

The approved design for the progress section of the public page, and its two cards, from the draft of 2026-10-15. The build plan is in the control tower: `control-tower/projects/openstage/notes/PROGRESS_PAGE_PLAN.md`. The live canvas, where every board can be clicked: https://claude.ai/artifact/2iBGXi9Mp1J4TZG6CQ4XYG (it opens on "New layout").

All files run on the founder's real data (the live page on 2026-10-14). Commits are counted per UTC day.

## What is here
- `mocks/PageMix.dc.html`: **the approved page layout.** Profile across the top; range tabs, project filter, a Bars | Lines switch and "Make a card"; the KPI row; the chart at 2/3 beside the numbered shipped and published list; the owner's untagged line and tag panel; the timeline below. `PageMix.src.dc.html` is the same page before `kit/core.js` was pasted in.
- `mocks/CardFootnotes.dc.html`: **the approved card for Bars** (chart left, numbered notes right).
- `mocks/CardJourney.dc.html`: **the approved card for Lines** (cumulative line with flags). The build changes it: circles instead of diamonds, and one colored line per project (see the plan).
- `mocks/PageFootnotes.dc.html`, `mocks/PageJourney.dc.html`: the two option pages the mix came from. Their chart code is better tested than the mix's: the Footnotes page has the least-movement disc placement, the Journey page the full flag engine.
- `specs/footnotes.md`, `specs/journey.md`: the full specs from the design round, with the shared rules (the pick, text rules, colors, filter, tagging, the card dialog).
- `sources/`: the generated mocks' sources. `sources/journey/engine.js` is the line and flag engine; `build.py` shows how page and card were assembled from it.
- `data.json`: the same data as plain JSON, for specs and a render script.
- `kit/core.js`: the shared logic every mock embeds: the data, calendar periods, buckets, the shared pick, tag overrides, colors, and card text fitting with the server's Inter widths (`CardText`). Port the pick and the text rules from here.
- `shots/`: renders of the page (Bars, Lines, a project after sample tags) and the two cards (2026 light, October dark).

The mocks are design-canvas components: their `renderVals` holds the layout logic to port.

## Rendering a mock
Needs Node (through nvm) and Google Chrome. Write output outside the repo.
```
doc/progress/kit/shot.sh doc/progress/mocks/PageMix.dc.html '{"props":{"viewer":"owner"},"state":{"chart":"line","range":"month"}}' /tmp/mix-lines-month.png 1280 1500
doc/progress/kit/shot.sh doc/progress/mocks/CardFootnotes.dc.html '{"props":{"range":"year","theme":"light"}}' /tmp/card-bars-year.png 1200 630
node doc/progress/kit/check.js doc/progress/mocks/PageMix.dc.html page
```
`shot.sh` takes props and page state as JSON, runs no events and draws a grey box in place of a card preview. `check.js` runs a mock's `renderVals` across ranges, projects, tags and states and reports errors or NaN.

Page state keys: `range` (week, month, year, all), `offset`, `project` (a project index), `chart` (bars, line), `tags` (entry id to project index, or -1 for no project), `hover`, `modal`, `tagOpen`. Card props: `range`, `theme`, `offset`, `project`, `tags` (JSON), `feature` (swapped-in entry ids).
