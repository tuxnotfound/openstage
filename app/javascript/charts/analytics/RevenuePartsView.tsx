import { useState } from "react"
import type { RevenueParts } from "../types"
import { Head, PANEL, RankedList } from "./RankedList"

// The MRR tab's parts under its chart, a panel each, side by side where
// both fit. Products: each one's MRR on the last day read on a bar as long
// as its share of the first, with its project's dot and its subscriptions,
// and Stripe's word that it is verified. MRR by week, or by month: a row
// each, newest first, with what it added or took, its arrow in the colour
// of its way, and where MRR stood at its end; the first thirteen, the rest
// behind Show all. With no product counted for a project, one line.

const SHOWN = 13
const VALUE = "min-w-[72px] whitespace-nowrap py-[7px] pl-[18px] text-right font-display text-[15px] font-semibold tracking-[-.02em] tabular-nums"

export default function RevenuePartsView({ revenue }: { revenue: RevenueParts }) {
  if (revenue.empty) return <div className={PANEL}><p className="os-note">{revenue.empty}</p></div>
  return (
    <div className="grid grid-cols-[repeat(auto-fit,minmax(min(100%,460px),1fr))] gap-4">
      {revenue.products.length > 0 && (
        <RankedList id="mrr-products" title="Products" unit={<span className="os-tag soft">Verified with Stripe</span>} ranked={{ rows: revenue.products, empty: null }} />
      )}
      {revenue.steps.rows.length > 0 && <Steps steps={revenue.steps} />}
    </div>
  )
}

function Steps({ steps }: { steps: RevenueParts["steps"] }) {
  const [all, setAll] = useState(false)
  const rows = all ? steps.rows : steps.rows.slice(0, SHOWN)
  return (
    <section className={PANEL} aria-labelledby="mrr-steps">
      <Head id="mrr-steps" title={steps.title} />
      <div className="mt-1.5 overflow-x-auto">
        <table className="w-full border-collapse text-sm">
          <caption className="sr-only">{steps.title}: what each added or took, and where MRR stood at its end</caption>
          <thead>
            <tr className="text-xs text-ink-3">
              <th scope="col" className="w-full pt-1.5 pb-2" />
              <th scope="col" className="whitespace-nowrap pt-1.5 pb-2 pl-[18px] text-right font-bold">Change</th>
              <th scope="col" className="whitespace-nowrap pt-1.5 pb-2 pl-[18px] text-right font-bold">MRR</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.label} className="border-t border-line">
                <th scope="row" className="py-[7px] text-left text-sm font-semibold">{row.label}</th>
                <td className={VALUE}>
                  {row.up !== null && (
                    <><span className={`text-[11px] ${row.up ? "text-up" : "text-down"}`} aria-hidden="true">{row.up ? "▲" : "▼"}</span><span className="sr-only">{row.up ? "up" : "down"}</span> </>
                  )}
                  {row.amount}
                </td>
                <td className={VALUE}>{row.mrr}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {!all && steps.rows.length > SHOWN && (
        <button type="button" className="os-btn2 sm mt-3" onClick={() => setAll(true)}>Show all {steps.rows.length}</button>
      )}
    </section>
  )
}
