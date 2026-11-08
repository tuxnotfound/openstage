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
    expect(RevenueDay.first.revenue_product).to eq(account.revenue_products.sole)
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
