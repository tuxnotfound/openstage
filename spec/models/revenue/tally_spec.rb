require "rails_helper"

RSpec.describe Revenue::Tally do
  let(:today) { Date.new(2026, 11, 7) }
  let(:tally) { described_class.new(today: today) }

  def line(from, to, monthly, subscription: "sub_1", customer: "cus_1", product_id: 1, currency: "usd")
    Revenue::Tally::Line.new(product_id: product_id, currency: currency, subscription: subscription, customer: customer, from: Date.parse(from), to: Date.parse(to), monthly: monthly)
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

  it "keeps a day with a customer paying and no MRR, as on a usage-based price" do
    tally.add(line("2026-10-01", "2026-11-01", 0))

    expect(on("2026-10-06")).to eq([ { revenue_product_id: 1, currency: "usd", mrr: 0, subscriptions: 1 } ])
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

  describe "the customers paying" do
    def customers_on(day)
      tally.customer_rows.select { |row| row[:day] == Date.parse(day) }.map { |row| row.slice(:product_ids, :customers) }
    end

    it "counts a customer with two subscriptions to one product once" do
      tally.add(line("2026-11-01", "2026-12-01", 1000))
      tally.add(line("2026-11-01", "2026-12-01", 500, subscription: "sub_2"))

      expect(customers_on("2026-11-07")).to eq([ { product_ids: [ 1 ], customers: 1 } ])
      expect(on("2026-11-07")).to eq([ { revenue_product_id: 1, currency: "usd", mrr: 1500, subscriptions: 2 } ])
    end

    it "counts a customer of two products once, under both, only on the days they pay for both" do
      tally.add(line("2026-10-01", "2026-12-01", 1000))
      tally.add(line("2026-10-10", "2026-10-20", 500, product_id: 2))

      expect(customers_on("2026-10-05")).to eq([ { product_ids: [ 1 ], customers: 1 } ])
      expect(customers_on("2026-10-15")).to eq([ { product_ids: [ 1, 2 ], customers: 1 } ])
      expect(customers_on("2026-10-25")).to eq([ { product_ids: [ 1 ], customers: 1 } ])
    end

    it "adds up customers paying for the same products, in any currency, and stops at today and at a day with none" do
      tally.add(line("2026-11-01", "2026-12-01", 1000))
      tally.add(line("2026-11-01", "2026-12-01", 1000, subscription: "sub_2", customer: "cus_2", currency: "eur"))
      tally.add(line("2026-10-01", "2026-10-05", 1000, subscription: "sub_3", customer: "cus_3"))

      expect(customers_on("2026-11-07")).to eq([ { product_ids: [ 1 ], customers: 2 } ])
      expect(customers_on("2026-11-08")).to be_empty
      expect(customers_on("2026-10-10")).to be_empty
    end

    it "does not count back-to-back periods twice on the day between them" do
      tally.add(line("2026-10-01", "2026-11-01", 1000))
      tally.add(line("2026-11-01", "2026-12-01", 1000))

      expect(customers_on("2026-11-01")).to eq([ { product_ids: [ 1 ], customers: 1 } ])
    end
  end
end
