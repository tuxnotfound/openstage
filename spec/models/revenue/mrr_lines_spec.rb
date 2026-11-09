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
      "sub_item_discounted" => stripe_subscription("active", items: { data: [ { id: "si_d", discounts: [ "di_on_item" ], price: {} } ] }) }
      .merge(charging)
  end
  # Subscriptions an example gives its current items.
  let(:charging) { {} }

  def stripe_subscription(status, **fields)
    Revenue::StripeSubscription.new({ status: status }.merge(fields))
  end

  def stripe_line(price: "price_m", amount: 1900, subscription: "sub_1", proration: false, product: "prod_1", discounts: [], taxes: [], item: nil,
                  from: Time.utc(2026, 10, 10, 23, 30), to: Time.utc(2026, 11, 10, 23, 30))
    { object: "line_item", amount: amount, currency: "usd", discount_amounts: discounts, taxes: taxes,
      parent: { type: "subscription_item_details", subscription_item_details: { subscription: subscription, proration: proration, subscription_item: item } },
      pricing: { type: "price_details", price_details: { price: price, product: product } },
      period: { start: from.to_i, end: to.to_i } }
  end

  # The lines one read of these invoice lines gives, oldest first.
  def counted(*lines, status: "paid", today: Date.new(2026, 12, 1), named: [])
    reader = described_class.new(products: { "prod_1" => 7 }, recurring: recurring, subscriptions: subscriptions, zone: zone, today: today)
    reader.read_discounts(named)
    lines.each { |line| reader.read(line, status) }
    [].tap { |given| reader.each_line { |tally_line| given << tally_line } }
  end

  def monthly(line)
    counted(line).sole.monthly
  end

  it "counts a monthly subscription's period at its price, on the builder's days" do
    expect(counted(stripe_line)).to eq([ Revenue::Tally::Line.new(product_id: 7, currency: "usd", subscription: "sub_1", customer: "sub_1",
                                                                  from: Date.new(2026, 10, 11), to: Date.new(2026, 11, 10), monthly: 1900) ])
  end

  it "says whose subscription it is" do
    subscriptions["sub_owned"] = stripe_subscription("active", customer: "cus_9")

    expect(counted(stripe_line(subscription: "sub_owned")).sole.customer).to eq("cus_9")
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
    it "counts an open one while Stripe collects it: a subscription active, past due, or cancelled, up to that moment" do
      expect(counted(stripe_line, status: "open").sole.monthly).to eq(1900)
      expect(counted(stripe_line(subscription: "sub_past_due"), status: "open").sole.monthly).to eq(1900)
      expect(counted(stripe_line(subscription: "sub_gone"), status: "open").sole.to).to eq(Date.new(2026, 10, 20))
    end

    it "does not count a draft or one given up on, even once its subscription is cancelled or resumed" do
      %w[draft uncollectible].product(%w[sub_1 sub_gone]).each do |status, subscription|
        expect(counted(stripe_line(subscription: subscription), status: status)).to be_empty
      end
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

    describe "whose coupon its invoice names" do
      def named(id, duration, **fields)
        { id: id, source: { coupon: { duration: duration } }, **fields }
      end

      it "takes a coupon's word from the first period: once is left out, the rest subtract" do
        expect(counted(discounted("di_1"), named: [ named("di_1", "once") ]).sole.monthly).to eq(1900)
        expect(counted(discounted("di_1"), named: [ named("di_1", "forever") ]).sole.monthly).to eq(1500)
        expect(counted(discounted("di_1"), named: [ named("di_1", "repeating") ]).sole.monthly).to eq(1500)
      end

      it "takes a once coupon's word over a subscription that still carries it" do
        expect(counted(discounted("di_lasting", subscription: "sub_discounted"), named: [ named("di_lasting", "once") ]).sole.monthly).to eq(1900)
      end

      it "goes by its periods when the coupon was deleted, and says nothing" do
        gone = { id: "di_1", source: { coupon: { id: "x", deleted: true } } }

        expect(counted(discounted("di_1"), named: [ gone ]).sole.monthly).to eq(1900)
        expect(counted(discounted("di_1"), discounted("di_1", from: Time.utc(2026, 11, 10, 23, 30), to: Time.utc(2026, 12, 10, 23, 30)), named: [ gone ]).map(&:monthly)).to eq([ 1500, 1500 ])
      end
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

  describe "a plan change" do
    let(:monthly) { { interval: "month", interval_count: 1, usage_type: "licensed" } }
    let(:yearly) { { interval: "year", interval_count: 1, usage_type: "licensed" } }

    def current(id: "si_1", price: "price_m", recurring: monthly, unit_amount: 1900, quantity: 1, created: Time.utc(2026, 1, 1), currency: "usd", **rest)
      { id: id, price: { id: price, product: "prod_1", recurring: recurring, unit_amount: unit_amount, currency: currency }, quantity: quantity, created: created.to_i, **rest }
    end

    def on(*items, status: "active", **fields)
      { "sub_now" => stripe_subscription(status, currency: "usd", items: { data: items, has_more: false }, **fields) }
    end

    def paid(from, to, **fields)
      stripe_line(subscription: "sub_now", item: "si_1", from: Time.utc(*from), to: Time.utc(*to), **fields)
    end

    # Each line as [its first day, the day after its last, its monthly amount].
    def spans(*lines, **options)
      counted(*lines, **options).sort_by(&:from).map { |line| [ line.from, line.to, line.monthly ] }
    end

    context "with no current items, as a subscription with too many for Stripe's answer" do
      let(:charging) { on(current, current(id: "si_2")).merge("sub_now" => stripe_subscription("active", currency: "usd", items: { data: [ current ], has_more: true })) }

      it "goes by its invoices alone" do
        expect(spans(paid([ 2026, 1, 1 ], [ 2026, 2, 1 ]), today: Date.new(2026, 1, 15))).to eq([ [ Date.new(2026, 1, 1), Date.new(2026, 2, 1), 1900 ] ])
      end
    end

    it "counts one line at a time for an item, so a new billing date does not double it" do
      first = stripe_line(item: "si_1", from: Time.utc(2026, 1, 1), to: Time.utc(2026, 2, 1))
      switched = stripe_line(item: "si_1", price: "price_y", amount: 22_800, from: Time.utc(2026, 1, 11), to: Time.utc(2027, 1, 11))

      expect(counted(first, switched).map { |line| [ line.from, line.to, line.monthly ] })
        .to eq([ [ Date.new(2026, 1, 1), Date.new(2026, 1, 11), 1900 ], [ Date.new(2026, 1, 11), Date.new(2027, 1, 11), 1900 ] ])
    end

    context "when a price changes with no new invoice" do
      let(:charging) { on(current(unit_amount: 500, quantity: 3)) }

      it "reads today at what it charges now, and the days before at what was invoiced" do
        expect(spans(paid([ 2026, 1, 1 ], [ 2026, 2, 1 ]), today: Date.new(2026, 1, 11)))
          .to eq([ [ Date.new(2026, 1, 1), Date.new(2026, 1, 11), 1900 ], [ Date.new(2026, 1, 11), Date.new(2026, 1, 12), 1500 ] ])
      end
    end

    context "when no invoice covers the days since the last one, as a switch to yearly in flexible billing" do
      let(:charging) { on(current(price: "price_y", recurring: yearly, unit_amount: 22_800)) }

      it "fills them with what it charges now" do
        expect(spans(paid([ 2026, 1, 1 ], [ 2026, 2, 1 ]), today: Date.new(2026, 2, 15)))
          .to eq([ [ Date.new(2026, 1, 1), Date.new(2026, 2, 1), 1900 ], [ Date.new(2026, 2, 1), Date.new(2026, 2, 16), 1900 ] ])
      end
    end

    context "with an item not invoiced yet" do
      let(:charging) { on(current(created: Time.utc(2026, 1, 20))) }

      it "counts from the day it was added" do
        expect(spans(today: Date.new(2026, 1, 25))).to eq([ [ Date.new(2026, 1, 20), Date.new(2026, 1, 26), 1900 ] ])
      end
    end

    context "with an item replaced by another" do
      let(:charging) { on(current(id: "si_2", unit_amount: 2000, created: Time.utc(2026, 1, 11))) }

      it "ends the old one where the new one began" do
        expect(spans(paid([ 2026, 1, 1 ], [ 2026, 2, 1 ]), today: Date.new(2026, 1, 20)))
          .to eq([ [ Date.new(2026, 1, 1), Date.new(2026, 1, 11), 1900 ], [ Date.new(2026, 1, 11), Date.new(2026, 1, 21), 2000 ] ])
      end
    end

    context "with a discount and tax" do
      let(:charging) { on(current(unit_amount: 2000, discounts: [ "di_on" ])) }
      let(:discounted) { [ { amount: 1000, discount: "di_on" } ] }

      it "keeps a discount its subscription still carries, and the tax's share" do
        line = paid([ 2026, 1, 1 ], [ 2026, 2, 1 ], amount: 2000, discounts: discounted, taxes: [ { amount: 187, tax_behavior: "inclusive" } ])

        expect(spans(line, today: Date.new(2026, 1, 11)).last.last).to eq(813)
      end
    end

    context "with a discount that has run out since its last invoice" do
      let(:charging) { on(current(unit_amount: 2000)) }

      it "reads today at the full price" do
        line = paid([ 2026, 1, 1 ], [ 2026, 2, 1 ], amount: 2000, discounts: [ { amount: 1000, discount: "di_gone" } ])

        expect(spans(line, today: Date.new(2026, 1, 11)).last.last).to eq(2000)
      end
    end

    context "with a discount on the customer, which no subscription carries" do
      let(:charging) { on(current(unit_amount: 2000)) }
      let(:line) { paid([ 2026, 1, 1 ], [ 2026, 2, 1 ], amount: 2000, discounts: [ { amount: 1000, discount: "di_c" } ]) }

      def now_with(duration, **fields)
        discount = { id: "di_c", subscription: nil, subscription_item: nil, source: { coupon: { duration: duration } }, **fields }
        counted(line, today: Date.new(2026, 1, 11), named: [ discount ]).last.monthly
      end

      it "reads today less a forever one, from the first period" do
        expect(now_with("forever")).to eq(1000)
      end

      it "reads today less a repeating one until it ends" do
        expect(now_with("repeating", end: Time.utc(2026, 3, 1).to_i)).to eq(1000)
        expect(now_with("repeating", end: Time.utc(2026, 1, 5).to_i)).to eq(2000)
      end

      it "reads today at the full price under a once one, or one taken off the customer" do
        expect(now_with("once")).to eq(2000)
        expect(now_with("forever", deleted: true)).to eq(2000)
      end
    end

    context "with a discount on the subscription its coupon says lasts, since taken off" do
      let(:charging) { on(current(unit_amount: 2000)) }

      it "reads today at the full price" do
        line = paid([ 2026, 1, 1 ], [ 2026, 2, 1 ], amount: 2000, discounts: [ { amount: 1000, discount: "di_s" } ])
        discount = { id: "di_s", subscription: "sub_now", source: { coupon: { duration: "forever" } } }

        expect(counted(line, today: Date.new(2026, 1, 11), named: [ discount ]).last.monthly).to eq(2000)
      end
    end

    context "with a price of no one amount" do
      let(:charging) { on(current(unit_amount: nil)) }

      it "reads today at what its last invoice charged, its tiers together" do
        first = paid([ 2026, 1, 1 ], [ 2026, 2, 1 ], amount: 1000)
        second = paid([ 2026, 1, 1 ], [ 2026, 2, 1 ], amount: 500)

        expect(spans(first, second, today: Date.new(2026, 1, 11)).map(&:last)).to eq([ 1000, 500, 1500 ])
      end
    end

    context "with a price in another currency than its subscription" do
      let(:charging) { on(current(unit_amount: 9999, currency: "eur")) }

      it "reads today at what its last invoice charged" do
        expect(spans(paid([ 2026, 1, 1 ], [ 2026, 2, 1 ]), today: Date.new(2026, 1, 11)).last.last).to eq(1900)
      end
    end

    context "with a usage-based price" do
      let(:charging) { on(current(price: "price_usage", recurring: { interval: "month", interval_count: 1, usage_type: "metered" }, unit_amount: nil, quantity: nil)) }

      it "adds nothing, and its customer is paying now, before any bill" do
        expect(counted(today: Date.new(2026, 1, 11)).sole).to have_attributes(monthly: 0, to: Date.new(2026, 1, 12))
      end
    end

    context "with a free price" do
      let(:charging) { on(current(unit_amount: 0)) }

      it "counts nothing" do
        expect(counted(today: Date.new(2026, 1, 11))).to be_empty
      end
    end

    it "gives nothing now while it is in a trial, unpaid, paused, or going away" do
      [ on(current, status: "trialing"), on(current, status: "unpaid"), on(current, status: "incomplete"), on(current, status: "canceled", canceled_at: Time.utc(2026, 1, 5).to_i),
        on(current, pause_collection: { behavior: "void" }), on(current, canceled_at: Time.utc(2026, 1, 5).to_i, cancel_at_period_end: true) ].each do |subscription|
        reader = described_class.new(products: { "prod_1" => 7 }, recurring: recurring, subscriptions: subscription, zone: zone, today: Date.new(2026, 1, 11))

        expect(reader.enum_for(:each_line).to_a).to be_empty
      end
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
