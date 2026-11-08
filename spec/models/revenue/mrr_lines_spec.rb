require "rails_helper"

RSpec.describe Revenue::MrrLines do
  let(:zone) { ActiveSupport::TimeZone["Europe/Lisbon"] }
  let(:recurring) do
    { "price_m" => { interval: "month", interval_count: 1, usage_type: "licensed" }, "price_y" => { interval: "year", interval_count: 1, usage_type: "licensed" },
      "price_w" => { interval: "week", interval_count: 2, usage_type: "licensed" }, "price_usage" => { interval: "month", interval_count: 1, usage_type: "metered" },
      "price_once" => nil }
  end
  let(:cancelled_at) { Time.utc(2026, 10, 20, 12).to_i }
  let(:subscriptions) do
    { "sub_1" => stripe_subscription("active"), "sub_past_due" => stripe_subscription("past_due"), "sub_unpaid" => stripe_subscription("unpaid"),
      "sub_incomplete" => stripe_subscription("incomplete"), "sub_paused" => stripe_subscription("active", pause_collection: { behavior: "mark_uncollectible" }),
      "sub_gone" => stripe_subscription("canceled", canceled_at: cancelled_at, ended_at: cancelled_at),
      "sub_ending" => stripe_subscription("active", canceled_at: cancelled_at, cancel_at_period_end: true),
      "sub_ended" => stripe_subscription("canceled", ended_at: cancelled_at),
      "sub_discounted" => stripe_subscription("active", discounts: [ "di_lasting" ]),
      "sub_item_discounted" => stripe_subscription("active", items: { data: [ { discounts: [ "di_on_item" ] } ] }) }
  end

  def stripe_subscription(status, **fields)
    Revenue::StripeSubscription.new({ status: status }.merge(fields))
  end

  def stripe_line(price: "price_m", amount: 1900, subscription: "sub_1", proration: false, product: "prod_1", discounts: [], taxes: [],
                  from: Time.utc(2026, 10, 10, 23, 30), to: Time.utc(2026, 11, 10, 23, 30))
    { object: "line_item", amount: amount, currency: "usd", discount_amounts: discounts, taxes: taxes,
      parent: { type: "subscription_item_details", subscription_item_details: { subscription: subscription, proration: proration } },
      pricing: { type: "price_details", price_details: { price: price, product: product } },
      period: { start: from.to_i, end: to.to_i } }
  end

  # The lines one read of these invoice lines gives, in order.
  def counted(*lines, status: "paid")
    reader = described_class.new(products: { "prod_1" => 7 }, recurring: recurring, subscriptions: subscriptions, zone: zone)
    [].tap do |given|
      lines.each { |line| reader.read(line, status) { |tally_line| given << tally_line } }
      reader.read_held { |tally_line| given << tally_line }
    end
  end

  def monthly(line)
    counted(line).sole.monthly
  end

  it "counts a monthly subscription's period at its price, on the builder's days" do
    expect(counted(stripe_line)).to eq([ Revenue::Tally::Line.new(product_id: 7, currency: "usd", subscription: "sub_1",
                                                                  from: Date.new(2026, 10, 11), to: Date.new(2026, 11, 10), monthly: 1900) ])
  end

  it "counts a yearly plan as a twelfth, a two-weekly one as 26 twelfths" do
    expect(monthly(stripe_line(price: "price_y", amount: 18_000))).to eq(1500)
    expect(monthly(stripe_line(price: "price_w", amount: 600))).to eq(1300)
  end

  it "ends a period the moment its subscription was cancelled, even one running on to its period's end" do
    expect(counted(stripe_line(subscription: "sub_gone")).sole.to).to eq(Date.new(2026, 10, 20))
    expect(counted(stripe_line(subscription: "sub_ending")).sole.to).to eq(Date.new(2026, 10, 20))
  end

  it "ends a period when its subscription ended, where Stripe gives no moment of cancelling" do
    expect(counted(stripe_line(subscription: "sub_ended")).sole.to).to eq(Date.new(2026, 10, 20))
  end

  it "leaves out prorations, one-off items and prices, products of no account, and free periods" do
    one_off = stripe_line.merge(parent: { type: "invoice_item_details", invoice_item_details: { invoice_item: "ii_1" } })

    expect([ stripe_line(proration: true), one_off, stripe_line(price: "price_once"), stripe_line(product: "prod_else"), stripe_line(amount: 0),
             stripe_line(subscription: "sub_discounted", discounts: [ { amount: 1900, discount: "di_lasting" } ]) ].flat_map { |line| counted(line) })
      .to be_empty
  end

  describe "an invoice not yet paid" do
    it "counts while Stripe collects it: a subscription active, past due, or cancelled, up to that moment" do
      expect(counted(stripe_line, status: "open").sole.monthly).to eq(1900)
      expect(counted(stripe_line, status: "draft").sole.monthly).to eq(1900)
      expect(counted(stripe_line(subscription: "sub_past_due"), status: "open").sole.monthly).to eq(1900)
      expect(counted(stripe_line(subscription: "sub_gone"), status: "uncollectible").sole.to).to eq(Date.new(2026, 10, 20))
    end

    it "does not count once Stripe has stopped collecting, or never began" do
      %w[sub_unpaid sub_incomplete sub_paused sub_unknown].each do |subscription|
        expect(counted(stripe_line(subscription: subscription), status: "open")).to be_empty
      end
    end

    it "counts what was paid on those same subscriptions" do
      expect(counted(stripe_line(subscription: "sub_unpaid"))).not_to be_empty
    end

    it "never counts a void one" do
      expect(counted(stripe_line, status: "void")).to be_empty
    end
  end

  describe "discounts" do
    def discounted(discount, **fields)
      stripe_line(discounts: [ { amount: 400, discount: discount } ], **fields)
    end

    it "leaves a one-off discount out: one no subscription carries, on one period" do
      expect(monthly(discounted("di_once"))).to eq(1900)
    end

    it "subtracts a discount its subscription or one of its items still carries" do
      expect(monthly(discounted("di_lasting", subscription: "sub_discounted"))).to eq(1500)
      expect(monthly(discounted("di_on_item", subscription: "sub_item_discounted"))).to eq(1500)
    end

    it "subtracts a discount over several periods, once it has run out too" do
      first = discounted("di_repeating")
      second = discounted("di_repeating", from: Time.utc(2026, 11, 10, 23, 30), to: Time.utc(2026, 12, 10, 23, 30))

      expect(counted(first, second).map(&:monthly)).to eq([ 1500, 1500 ])
    end

    it "does not call one period's discount lasting for being on two of its lines" do
      expect(counted(discounted("di_once"), discounted("di_once")).map(&:monthly)).to eq([ 1900, 1900 ])
    end
  end

  describe "usage-based prices" do
    it "adds nothing to MRR, and its period still counts its customer as paying" do
      expect(monthly(stripe_line(price: "price_usage", amount: 3000))).to eq(0)
    end

    it "does not count a customer who used nothing" do
      expect(counted(stripe_line(price: "price_usage", amount: 0))).to be_empty
    end
  end

  describe "tax" do
    def tax(amount, behavior)
      { amount: amount, tax_behavior: behavior, taxable_amount: 1626, type: "tax_rate_details" }
    end

    it "takes off tax a price includes" do
      expect(monthly(stripe_line(amount: 2000, taxes: [ tax(374, "inclusive") ]))).to eq(1626)
    end

    it "leaves an amount alone when tax sits on top of it" do
      expect(monthly(stripe_line(amount: 2000, taxes: [ tax(460, "exclusive") ]))).to eq(2000)
    end

    it "takes off the tax's share of the full price under a one-off discount" do
      line = stripe_line(amount: 2000, discounts: [ { amount: 1000, discount: "di_once" } ], taxes: [ tax(187, "inclusive") ])

      expect(monthly(line)).to eq(1626)
    end

    it "counts the price with nothing to go by, under a one-off discount of all of it" do
      expect(monthly(stripe_line(amount: 2000, discounts: [ { amount: 2000, discount: "di_once" } ]))).to eq(2000)
    end
  end
end
