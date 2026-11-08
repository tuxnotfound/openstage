require "rails_helper"

RSpec.describe Billing::ConfirmCheckoutService do
  let(:user) { create(:user, pro: false) }
  let(:checkout) { { user_id: user.id.to_s, paid: true, customer: "cus_1", subscription: "sub_1", subscription_status: "active" } }

  def confirm(read = checkout)
    allow(StripeGateway).to receive(:checkout_session).with("cs_1").and_return(read)
    described_class.new(user: user, session_id: "cs_1")
  end

  it "makes the builder Pro on a paid checkout with its subscription running" do
    expect(confirm.call).to be(true)
    expect(user.reload).to have_attributes(pro: true, stripe_subscription_id: "sub_1")
  end

  it "refuses another builder's checkout" do
    expect(confirm(checkout.merge(user_id: "0")).call).to be(false)
    expect(user.reload).not_to be_pro
  end

  it "refuses an unpaid checkout" do
    expect(confirm(checkout.merge(paid: false)).call).to be(false)
    expect(user.reload).not_to be_pro
  end

  it "refuses a cancelled plan's old checkout, opened again" do
    expect(confirm(checkout.merge(subscription_status: "canceled")).call).to be(false)
    expect(user.reload).not_to be_pro
  end

  it "refuses a checkout Stripe does not know" do
    allow(StripeGateway).to receive(:checkout_session).and_raise(ApplicationGateway::NotFound)

    service = described_class.new(user: user, session_id: "cs_gone")

    expect(service.call).to be(false)
    expect(service.errors.full_messages.first).to eq(described_class::NOT_CONFIRMED)
  end

  it "refuses without a checkout" do
    service = described_class.new(user: user, session_id: "")

    expect(service.call).to be(false)
  end
end
