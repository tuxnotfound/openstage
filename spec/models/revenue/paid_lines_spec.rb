require "rails_helper"

RSpec.describe Revenue::PaidLines do
  let(:zone) { ActiveSupport::TimeZone["Europe/Lisbon"] }
  let(:recurring) do
    { "price_m" => { interval: "month", interval_count: 1 }, "price_y" => { interval: "year", interval_count: 1 },
      "price_w" => { interval: "week", interval_count: 2 }, "price_once" => nil }
  end
  let(:lines) { described_class.new(products: { "prod_1" => 7 }, recurring: recurring, endings: { "sub_gone" => Time.utc(2026, 10, 20, 12).to_i }, zone: zone) }

  def stripe_line(price: "price_m", amount: 1900, subscription: "sub_1", proration: false, product: "prod_1", discounts: [],
                  from: Time.utc(2026, 10, 10, 23, 30), to: Time.utc(2026, 11, 10, 23, 30))
    { object: "line_item", amount: amount, currency: "usd", discount_amounts: discounts,
      parent: { type: "subscription_item_details", subscription_item_details: { subscription: subscription, proration: proration } },
      pricing: { type: "price_details", price_details: { price: price, product: product } },
      period: { start: from.to_i, end: to.to_i } }
  end

  it "counts a monthly subscription's period at its price, on the builder's days" do
    expect(lines.tally_line(stripe_line)).to eq(Revenue::Tally::Line.new(product_id: 7, currency: "usd", subscription: "sub_1",
                                                                         from: Date.new(2026, 10, 11), to: Date.new(2026, 11, 10), monthly: 1900))
  end

  it "counts a yearly plan as a twelfth, a two-weekly one as 26 twelfths, after discounts" do
    expect(lines.tally_line(stripe_line(price: "price_y", amount: 18_000)).monthly).to eq(1500)
    expect(lines.tally_line(stripe_line(price: "price_w", amount: 600)).monthly).to eq(1300)
    expect(lines.tally_line(stripe_line(discounts: [ { amount: 400, discount: "di_1" } ])).monthly).to eq(1500)
  end

  it "ends a period on the day its subscription ended" do
    expect(lines.tally_line(stripe_line(subscription: "sub_gone")).to).to eq(Date.new(2026, 10, 20))
  end

  it "leaves out prorations, one-off items and prices, products of no account, and free periods" do
    one_off = stripe_line.merge(parent: { type: "invoice_item_details", invoice_item_details: { invoice_item: "ii_1" } })

    expect([ stripe_line(proration: true), one_off, stripe_line(price: "price_once"), stripe_line(product: "prod_else"),
             stripe_line(amount: 0), stripe_line(discounts: [ { amount: 1900, discount: "di_all" } ]) ].map { |line| lines.tally_line(line) })
      .to all(be_nil)
  end
end
