require "rails_helper"

RSpec.describe Revenue::Tally do
  let(:today) { Date.new(2026, 11, 7) }
  let(:tally) { described_class.new(today: today) }

  def line(from, to, monthly, subscription: "sub_1", product_id: 1, currency: "usd")
    Revenue::Tally::Line.new(product_id: product_id, currency: currency, subscription: subscription, from: Date.parse(from), to: Date.parse(to), monthly: monthly)
  end

  def on(day)
    tally.rows.select { |row| row[:day] == Date.parse(day) }.map { |row| row.slice(:revenue_product_id, :currency, :mrr, :subscriptions) }
  end

  it "counts a subscription's paid months back to back, from its first day to today" do
    tally.add(line("2026-09-10", "2026-10-10", 1900))
    tally.add(line("2026-10-10", "2026-11-10", 1900))

    expect(tally.rows.map { |row| row[:day] }).to eq((Date.new(2026, 9, 10)..today).to_a)
    expect(on("2026-10-10")).to eq([ { revenue_product_id: 1, currency: "usd", mrr: 1900, subscriptions: 1 } ])
  end

  it "adds subscriptions together, and keeps no row for a day without revenue" do
    tally.add(line("2026-10-01", "2026-10-11", 1900))
    tally.add(line("2026-10-05", "2026-10-11", 1500, subscription: "sub_2"))

    expect(on("2026-10-06")).to eq([ { revenue_product_id: 1, currency: "usd", mrr: 3400, subscriptions: 2 } ])
    expect(on("2026-10-11")).to be_empty
  end

  it "counts a subscription once on a day two of its lines cover" do
    tally.add(line("2026-11-01", "2026-12-01", 1000))
    tally.add(line("2026-11-01", "2026-12-01", 500))

    expect(on("2026-11-07")).to eq([ { revenue_product_id: 1, currency: "usd", mrr: 1500, subscriptions: 1 } ])
  end

  it "keeps each product and currency apart, and rounds only the day's total" do
    tally.add(line("2026-11-01", "2027-11-01", Rational(10_000, 12)))
    tally.add(line("2026-11-01", "2027-11-01", Rational(10_000, 12), subscription: "sub_2"))
    tally.add(line("2026-11-01", "2026-12-01", 900, product_id: 2, currency: "eur"))

    expect(on("2026-11-07")).to contain_exactly({ revenue_product_id: 1, currency: "usd", mrr: 1667, subscriptions: 2 },
                                                { revenue_product_id: 2, currency: "eur", mrr: 900, subscriptions: 1 })
  end
end
