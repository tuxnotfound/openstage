import { describe, expect, test, vi } from "vitest"
import { ViewStore } from "../../app/javascript/charts/viewStore"

describe("ViewStore", () => {
  test("serves a seeded view without asking", async () => {
    const fetcher = vi.fn()
    const store = new ViewStore<string>(10, fetcher)
    store.seed("/a", "A")

    await expect(store.get("/a")).resolves.toBe("A")
    expect(fetcher).not.toHaveBeenCalled()
  })

  test("asks once per view, however often it is wanted", async () => {
    const fetcher = vi.fn(async (url: string) => `view of ${url}`)
    const store = new ViewStore<string>(10, fetcher)

    store.prefetch("/b")
    const [first, second] = await Promise.all([store.get("/b"), store.get("/b")])

    expect([first, second]).toEqual(["view of /b", "view of /b"])
    expect(fetcher).toHaveBeenCalledTimes(1)
  })

  test("drops the least recently used view past its limit", async () => {
    const fetcher = vi.fn(async (url: string) => url)
    const store = new ViewStore<string>(2, fetcher)

    await store.get("/1")
    await store.get("/2")
    await store.get("/1")
    await store.get("/3")
    await store.get("/1")
    await store.get("/2")

    expect(store.size).toBe(2)
    expect(fetcher.mock.calls.map(([url]) => url)).toEqual(["/1", "/2", "/3", "/2"])
  })

  test("forgets a view that failed, so asking again asks again", async () => {
    const fetcher = vi.fn().mockRejectedValueOnce(new Error("500")).mockResolvedValueOnce("ok")
    const store = new ViewStore<string>(10, fetcher)

    await expect(store.get("/c")).rejects.toThrow("500")
    await expect(store.get("/c")).resolves.toBe("ok")
    expect(fetcher).toHaveBeenCalledTimes(2)
  })

  test("swallows a failed prefetch", async () => {
    const store = new ViewStore<string>(10, async () => { throw new Error("offline") })

    expect(() => store.prefetch("/d")).not.toThrow()
    await new Promise((resolve) => setTimeout(resolve, 0))
    expect(store.size).toBe(0)
  })
})
