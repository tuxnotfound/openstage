// The views an island has fetched, by URL, so a view seen once comes back at
// once and a prefetched one is ready on the click. The least recently used go
// first past the limit; a failed fetch is forgotten, so trying again asks again.
export class ViewStore<T> {
  private readonly views = new Map<string, Promise<T>>()

  constructor(private readonly limit = 40, private readonly fetcher: (url: string) => Promise<T> = fetchJson) {}

  seed(url: string, view: T): void {
    this.remember(url, Promise.resolve(view))
  }

  get(url: string): Promise<T> {
    const known = this.views.get(url)
    if (known) {
      this.remember(url, known)
      return known
    }
    const view = this.fetcher(url).catch((error: unknown) => {
      if (this.views.get(url) === view) this.views.delete(url)
      throw error
    })
    this.remember(url, view)
    return view
  }

  prefetch(url: string): void {
    this.get(url).catch(() => undefined)
  }

  // After a change on the server every view kept may be out of date.
  clear(): void {
    this.views.clear()
  }

  get size(): number {
    return this.views.size
  }

  private remember(url: string, view: Promise<T>): void {
    this.views.delete(url)
    this.views.set(url, view)
    for (const oldest of this.views.keys()) {
      if (this.views.size <= this.limit) break
      this.views.delete(oldest)
    }
  }
}

async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
  if (!response.ok) throw new Error(`${response.status} for ${url}`)
  return (await response.json()) as T
}
