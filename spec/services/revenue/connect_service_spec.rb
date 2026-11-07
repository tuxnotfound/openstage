require "rails_helper"

RSpec.describe Revenue::ConnectService do
  let(:user) { create(:user) }
  let(:page) { { data: [], has_more: false } }

  before do
    %i[products prices subscriptions invoices].each { |list| allow(StripeGateway).to receive(list).and_return(page) }
  end

  def connect(key)
    described_class.new(user: user, provider: "stripe", api_key: key)
  end

  def refusal(status)
    ApplicationGateway::Unauthorized.new(status: status)
  end

  it "keeps a restricted key that reads everything MRR is made of" do
    service = connect("rk_test_ok")

    expect(service.call).to be(true)
    expect(user.revenue_accounts.sole).to have_attributes(provider: "stripe", api_key: "rk_test_ok")
    expect(service.account).to eq(user.revenue_accounts.sole)
  end

  it "replaces the key when the builder connects again" do
    connect("rk_test_old").call!
    connect("rk_test_new").call!

    expect(user.revenue_accounts.sole.api_key).to eq("rk_test_new")
  end

  it "refuses a secret key, which can also charge and refund, without trying it" do
    service = connect("sk_live_full")

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "That is a secret key, which can also charge and refund. Create a restricted key that only reads." ])
    expect(StripeGateway).not_to have_received(:products)
  end

  it "refuses anything that is not a restricted key" do
    expect(connect("pk_live_public").call).to be(false)
    expect(connect("").call).to be(false)
    expect(user.revenue_accounts).to be_empty
  end

  it "refuses a test key in production" do
    allow(Rails.env).to receive(:production?).and_return(true)
    service = connect("rk_test_ok")

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "Paste a restricted key from Stripe: it starts with rk_live_." ])
  end

  it "names every read the key lacks" do
    allow(StripeGateway).to receive(:subscriptions).and_raise(refusal(403))
    allow(StripeGateway).to receive(:invoices).and_raise(refusal(403))
    service = connect("rk_test_partial")

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq(
      [ "This key cannot read Subscriptions and Invoices. In Stripe, give it Read on Products, Prices, Subscriptions and Invoices." ]
    )
    expect(user.revenue_accounts).to be_empty
  end

  it "stops at a key Stripe does not know" do
    allow(StripeGateway).to receive(:products).and_raise(refusal(401))
    service = connect("rk_test_gone")

    expect(service.call).to be(false)
    expect(service.errors.full_messages).to eq([ "Stripe does not know this key. Copy it again from Stripe's API keys page." ])
    expect(StripeGateway).not_to have_received(:prices)
  end

  it "refuses a provider Openstage does not read" do
    expect(described_class.new(user: user, provider: "paddle", api_key: "rk_test_ok").call).to be(false)
  end
end
