# Week card design references

The approved designs for the week card templates, and the tools to render them. The build plan is in the control tower: `control-tower/projects/openstage/WEEK_CARD_PLAN.md`.

- `mocks/changelog.dc.html`: Changelog, the professional template, and the default.
- `mocks/star_chart.dc.html`: Star Chart, the week as a night sky with a persona.
- `mocks/pixel_stage.dc.html`: Pixel Stage, the week as a game level. Its character gets a redesign later.
- `mocks/data.json`: the real weeks 41, 40 and 38 the mocks were checked against. Fields marked invented are filler.

Each mock is a design-canvas component. Its `renderVals` holds the layout logic (fitting, wrapping, folding, persona rules) that the Rails port reproduces. Its props pick the week and theme, and some mocks embed extra test weeks: long names, six projects, a week with no commits.

## Rendering a mock
```
doc/week_cards/tools/shot.sh doc/week_cards/mocks/changelog.dc.html '{"week":"w41","theme":"light"}' /tmp/changelog-w41-light.png
```
It needs Node (through nvm) and Google Chrome. Fonts load from Google Fonts. To screenshot an HTML page of the app's own card, use `tools/htmlshot.sh <page.html> <out.png>`.

Props each mock takes:
- **changelog:**
  - `week`: w41, w40, w38, or the invented wx (stress), w0 (no commits, one post) and w7 (seven days);
  - `theme`: light or dark;
  - `code`: show or hide;
  - `identity`: tux, mid or long, for name-length tests.
- **star_chart:**
  - `week`: w41, w40, w38, or the invented z0 (one post), z6 (six projects), zl (a launch, no commits), zc (comeback) and zr (record);
  - `theme`: dark or light.
- **pixel_stage:**
  - `week`: w41, w40, w38, or the invented zero, wide and edge;
  - `theme`: dark or light.
