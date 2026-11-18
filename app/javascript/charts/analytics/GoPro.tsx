import { csrfToken } from "../filter/ProjectsTable"
import type { LockedView } from "../types"

// A tab Free does not open: what it shows on Pro, and the dashboard's
// button to Pro, which posts to checkout outside Turbo, as the dashboard's
// does. Its words are the server's.
export default function GoPro({ view }: { view: LockedView }) {
  return (
    <section className="os-panel p-[clamp(16px,1.7vw,24px)]" aria-label={view.tabs.find((tab) => tab.key === view.tab)?.label}>
      <p className="os-p text-ink">{view.pitch}</p>
      <form method="post" action={view.checkout.path} className="mt-[18px]" data-turbo="false">
        <input type="hidden" name="authenticity_token" value={csrfToken()} />
        <button type="submit" className="os-btn">{view.checkout.label}</button>
      </form>
    </section>
  )
}
