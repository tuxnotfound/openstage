import { written } from "../filter/lines"

// The switch above analytics' panels: those of the builder's websites, which
// it opens on and its URL leaves out, or those of their pages on Openstage
// (panels=openstage). Both sets come with every view, so the switch asks
// for nothing; the URL names it, so a link, a reload and Back show the same
// panels.

export type PanelSet = "websites" | "openstage"

export const PANELS_PARAM = "panels"

// The panels a page's address names: the websites' for none, or for a name
// it does not know, as the server reads it (AnalyticsController).
export function panelsIn(href: string): PanelSet {
  return new URL(href).searchParams.get(PANELS_PARAM) === "openstage" ? "openstage" : "websites"
}

// The page's address with other panels: its other params and its hash stay,
// and the websites' leave the param out.
export function panelsUrl(href: string, panels: PanelSet): string {
  const url = new URL(href)
  if (panels === "websites") url.searchParams.delete(PANELS_PARAM)
  else url.searchParams.set(PANELS_PARAM, panels)
  return written(url)
}
