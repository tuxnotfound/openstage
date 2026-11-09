require "rails_helper"

RSpec.describe Revenue::ReadService do
  let(:user) { create(:user, time_zone: "UTC") }
  let(:account) { user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok") }
  let(:last_page) { { data: [], has_more: false } }

  def line(subscription, from, to, amount: 1900, price: "price_m")
    { object: "line_item", amount: amount, currency: "usd", discount_amounts: [],
      parent: { type: "subscription_item_details", subscription_item_details: { subscription: subscription, proration: false } },
      pricing: { type: "price_details", price_details: { price: price, product: "prod_1" } },
      period: { start: Time.utc(*from).to_i, end: Time.utc(*to).to_i } }
  end

  def invoice(id, *lines, more: false, status: "paid")
    { id: id, object: "invoice", status: status, lines: { object: "list", data: lines, has_more: more } }
  end

  before do
    travel_to Time.utc(2026, 11, 7, 5)
    allow(StripeGateway).to receive(:products).and_return(data: [ { id: "prod_1", name: "Shipnote Pro", active: true } ], has_more: false)
    allow(StripeGateway).to receive(:prices)
      .and_return(data: [ { id: "price_m", recurring: { interval: "month", interval_count: 1 } } ], has_more: false)
    allow(StripeGateway).to receive(:subscriptions).with("rk_test_ok", status: "all", limit: 100)
                                                   .and_return(data: [ { id: "sub_1", status: "active" } ], has_more: false)
  end

  def days
    RevenueDay.order(:day).pluck(:day, :mrr, :subscriptions)
  end

  it "reads every invoice into the product's days, from the first sale to today" do
    allow(StripeGateway).to receive(:invoices).with("rk_test_ok", limit: 100)
                                              .and_return(data: [ invoice("in_2", line("sub_1", [ 2026, 11, 1 ], [ 2026, 12, 1 ])) ], has_more: true)
    allow(StripeGateway).to receive(:invoices).with("rk_test_ok", limit: 100, starting_after: "in_2")
                                              .and_return(data: [ invoice("in_1", line("sub_1", [ 2026, 10, 1 ], [ 2026, 11, 1 ])) ], has_more: false)

    described_class.new(account: account).call!

    expect(days.first).to eq([ Date.new(2026, 10, 1), 1900, 1 ])
    expect(days.last).to eq([ Date.new(2026, 11, 7), 1900, 1 ])
    expect(days.size).to eq(38)
    expect(account.reload.read_at).to eq(Time.current)
    expect(account.read_through).to eq(Date.new(2026, 11, 7))
    expect(RevenueDay.first.revenue_product).to eq(account.revenue_products.sole)
  end

  it "names the day it counted, when it ends after midnight" do
    allow(StripeGateway).to receive(:invoices) do
      travel_to Time.utc(2026, 11, 8, 0, 1)
      { data: [ invoice("in_1", line("sub_1", [ 2026, 11, 1 ], [ 2026, 12, 1 ])) ], has_more: false }
    end

    described_class.new(account: account).call!

    expect(days.last).to eq([ Date.new(2026, 11, 7), 1900, 1 ])
    expect(account.reload).to have_attributes(read_through: Date.new(2026, 11, 7), read_at: Time.utc(2026, 11, 8, 0, 1))
  end

  describe "a customer's discount and products" do
    let(:two_products) do
      [ { id: "sub_1", status: "active", customer: "cus_1" }, { id: "sub_2", status: "active", customer: "cus_1" }, { id: "sub_3", status: "active", customer: "cus_2" } ]
    end

    before do
      allow(StripeGateway).to receive(:products).and_return(data: [ { id: "prod_1", name: "Shipnote Pro", active: true }, { id: "prod_2", name: "Add-on", active: true } ], has_more: false)
      allow(StripeGateway).to receive(:subscriptions).and_return(data: two_products, has_more: false)
    end

    def of_product(subscription, product)
      line(subscription, [ 2026, 11, 1 ], [ 2026, 12, 1 ]).deep_merge(pricing: { price_details: { product: product } })
    end

    it "keeps how many customers paid for which products, in place of the last read's" do
      allow(StripeGateway).to receive(:invoices).and_return(data: [ invoice("in_1", of_product("sub_1", "prod_1"), of_product("sub_2", "prod_2"), of_product("sub_3", "prod_1")) ], has_more: false)
      account.revenue_customer_days.create!(day: Date.new(2026, 1, 1), product_ids: [ 0 ], customers: 5)

      described_class.new(account: account).call!

      prod_1, prod_2 = account.revenue_products.order(:external_id).pluck(:id)
      today = account.revenue_customer_days.where(day: Date.new(2026, 11, 7)).pluck(:product_ids, :customers)
      expect(today).to contain_exactly([ [ prod_1, prod_2 ], 1 ], [ [ prod_1 ], 1 ])
      expect(account.revenue_customer_days.minimum(:day)).to eq(Date.new(2026, 11, 1))
    end

    it "subtracts a forever coupon on the customer from its first invoice, as it names it" do
      discounted = line("sub_3", [ 2026, 11, 1 ], [ 2026, 12, 1 ]).merge(discount_amounts: [ { amount: 900, discount: "di_c" } ])
      named = invoice("in_1", discounted).merge(discounts: [ { id: "di_c", subscription: nil, source: { coupon: { duration: "forever" } } } ])
      allow(StripeGateway).to receive(:invoices).and_return(data: [ named ], has_more: false)

      described_class.new(account: account).call!

      expect(days.last).to eq([ Date.new(2026, 11, 7), 1000, 1 ])
    end
  end

  describe "an inline price" do
    let(:inline) { line("sub_gone", [ 2026, 10, 1 ], [ 2026, 10, 15 ], price: "price_inline") }

    before do
      allow(StripeGateway).to receive(:subscriptions).and_return(data: [ { id: "sub_gone", status: "canceled", ended_at: Time.utc(2026, 10, 15).to_i } ], has_more: false)
      allow(StripeGateway).to receive(:invoices).and_return(data: [ invoice("in_1", inline) ], has_more: false)
    end

    it "reads one on no list by its id, once" do
      allow(StripeGateway).to receive(:price).with("rk_test_ok", "price_inline").and_return(recurring: { interval: "month", interval_count: 1 })

      described_class.new(account: account).call!

      expect(days.first).to eq([ Date.new(2026, 10, 1), 1900, 1 ])
      expect(StripeGateway).to have_received(:price).once
    end

    it "leaves it out if Stripe no longer has it" do
      allow(StripeGateway).to receive(:price).and_raise(ApplicationGateway::NotFound.new(status: 404))

      described_class.new(account: account).call!

      expect(days).to be_empty
    end

    it "takes a current one from its subscription, with no asking" do
      item = { id: "si_1", quantity: 1, created: Time.utc(2026, 11, 1).to_i, price: { id: "price_inline", product: "prod_1", currency: "usd", unit_amount: 900, recurring: { interval: "month", interval_count: 1 } } }
      allow(StripeGateway).to receive(:subscriptions).and_return(data: [ { id: "sub_now", status: "active", currency: "usd", items: { data: [ item ], has_more: false } } ], has_more: false)
      allow(StripeGateway).to receive(:invoices).and_return(last_page)
      allow(StripeGateway).to receive(:price)

      described_class.new(account: account).call!

      expect(days.last).to eq([ Date.new(2026, 11, 7), 900, 1 ])
      expect(StripeGateway).not_to have_received(:price)
    end
  end

  it "keeps counting a past-due subscription on its open invoice, and not a void one" do
    allow(StripeGateway).to receive(:subscriptions).and_return(data: [ { id: "sub_1", status: "past_due" } ], has_more: false)
    allow(StripeGateway).to receive(:invoices).and_return(data: [ invoice("in_2", line("sub_1", [ 2026, 11, 1 ], [ 2026, 12, 1 ]), status: "open"),
                                                                  invoice("in_1", line("sub_1", [ 2026, 9, 1 ], [ 2026, 10, 1 ]), status: "void") ], has_more: false)

    described_class.new(account: account).call!

    expect(days.first).to eq([ Date.new(2026, 11, 1), 1900, 1 ])
    expect(days.last).to eq([ Date.new(2026, 11, 7), 1900, 1 ])
  end

  it "counts a discounted line once every invoice is read, so a discount over several periods is known" do
    discounted = ->(from, to) { line("sub_1", from, to).merge(discount_amounts: [ { amount: 400, discount: "di_1" } ]) }
    allow(StripeGateway).to receive(:invoices).and_return(data: [ invoice("in_2", discounted.call([ 2026, 11, 1 ], [ 2026, 12, 1 ])),
                                                                  invoice("in_1", discounted.call([ 2026, 10, 1 ], [ 2026, 11, 1 ])) ], has_more: false)

    described_class.new(account: account).call!

    expect(days.map(&:second).uniq).to eq([ 1500 ])
  end

  it "stops a subscription the moment it was cancelled, though its paid period runs on" do
    allow(StripeGateway).to receive(:subscriptions).and_return(data: [ { id: "sub_1", status: "active", cancel_at_period_end: true, canceled_at: Time.utc(2026, 11, 5, 12).to_i } ], has_more: false)
    allow(StripeGateway).to receive(:invoices).and_return(data: [ invoice("in_1", line("sub_1", [ 2026, 11, 1 ], [ 2026, 12, 1 ])) ], has_more: false)

    described_class.new(account: account).call!

    expect(days.last).to eq([ Date.new(2026, 11, 4), 1900, 1 ])
  end

  it "reads the rest of an invoice's lines when it carries only the first" do
    allow(StripeGateway).to receive(:invoices).and_return(data: [ invoice("in_1", more: true) ], has_more: false)
    allow(StripeGateway).to receive(:invoice_lines).with("rk_test_ok", "in_1", limit: 100)
                                                   .and_return(data: [ line("sub_1", [ 2026, 11, 1 ], [ 2026, 12, 1 ]).merge(id: "il_1") ], has_more: false)

    described_class.new(account: account).call!

    expect(days.last).to eq([ Date.new(2026, 11, 7), 1900, 1 ])
  end

  it "replaces what the last read wrote" do
    allow(StripeGateway).to receive(:invoices).and_return(data: [ invoice("in_1", line("sub_1", [ 2026, 11, 1 ], [ 2026, 12, 1 ])) ], has_more: false)
    described_class.new(account: account).call!
    allow(StripeGateway).to receive(:invoices).and_return(last_page)

    described_class.new(account: account).call!

    expect(RevenueDay.count).to eq(0)
  end

  describe "a product with no sale" do
    before do
      account.update!(created_at: Time.utc(2026, 11, 1, 12))
      allow(StripeGateway).to receive(:prices)
        .and_return(data: [ { id: "price_new", product: "prod_1", currency: "eur", recurring: { interval: "month", interval_count: 1 } },
                            { id: "price_old", product: "prod_1", currency: "usd", recurring: { interval: "month", interval_count: 1 } } ], has_more: false)
    end

    it "stands at nothing from the day Stripe was connected, in its newest price's currency" do
      allow(StripeGateway).to receive(:invoices).and_return(last_page)

      described_class.new(account: account).call!

      expect(RevenueDay.pluck(:day, :currency, :mrr, :subscriptions)).to eq([ [ Date.new(2026, 11, 1), "eur", 0, 0 ] ])
    end

    it "stands at nothing when a subscription was cancelled the day it began" do
      allow(StripeGateway).to receive(:subscriptions).and_return(data: [ { id: "sub_1", status: "canceled", canceled_at: Time.utc(2026, 10, 1, 12).to_i } ], has_more: false)
      allow(StripeGateway).to receive(:invoices).and_return(data: [ invoice("in_1", line("sub_1", [ 2026, 10, 1 ], [ 2026, 11, 1 ], price: "price_new")) ], has_more: false)

      described_class.new(account: account).call!

      expect(RevenueDay.pluck(:mrr, :subscriptions)).to eq([ [ 0, 0 ] ])
    end

    it "writes no such day once it has sold" do
      allow(StripeGateway).to receive(:invoices).and_return(data: [ invoice("in_1", line("sub_1", [ 2026, 11, 5 ], [ 2026, 12, 5 ], price: "price_new")) ], has_more: false)

      described_class.new(account: account).call!

      expect(days.first).to eq([ Date.new(2026, 11, 5), 1900, 1 ])
    end
  end

  it "records a key Stripe refuses, keeps what it read, and fails nothing" do
    product = account.revenue_products.create!(external_id: "prod_1", name: "Shipnote Pro")
    product.revenue_days.create!(day: Date.new(2026, 11, 1), currency: "usd", mrr: 100, subscriptions: 1)
    allow(StripeGateway).to receive(:products).and_raise(ApplicationGateway::Unauthorized.new(status: 401))

    expect(described_class.new(account: account).call).to be(true)

    expect(account.reload.refused_at).to eq(Time.current)
    expect(RevenueDay.count).to eq(1)
  end

  it "clears it on the next read that works" do
    account.update!(refused_at: 1.day.ago)
    allow(StripeGateway).to receive(:invoices).and_return(last_page)

    described_class.new(account: account).call!

    expect(account.reload.refused_at).to be_nil
  end
end
