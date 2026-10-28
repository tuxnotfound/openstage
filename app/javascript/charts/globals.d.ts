// What the islands read from the page's own scripts: Turbo, which
// turbo-rails puts on window.
interface Window {
  Turbo?: { cache: { exemptPageFromCache(): void } }
}
