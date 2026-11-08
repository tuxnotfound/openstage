require "rails_helper"

RSpec.describe Billing::StartProService do
  let(:user) { create(:user, pro: false) }

  def start(subscription_id = "sub_1")
    described_class.new(user: user, customer_id: "cus_1", subscription_id: subscription_id).call!
  end

  it "makes the builder Pro on the subscription" do
    start

    expect(user.reload).to have_attributes(pro: true, stripe_customer_id: "cus_1", stripe_subscription_id: "sub_1")
    expect(user.pro_since).to be_present
  end

  it "changes nothing the second time, so the plan keeps the day it began" do
    start
    began = 3.days.ago.change(usec: 0)
    user.update!(pro_since: began)

    start

    expect(user.reload.pro_since).to eq(began)
  end

  it "starts again on a new subscription" do
    start
    user.update!(pro_since: 3.days.ago)

    start("sub_2")

    expect(user.reload.stripe_subscription_id).to eq("sub_2")
    expect(user.pro_since).to be > 1.minute.ago
  end

  it "refuses without a subscription" do
    expect(described_class.new(user: user, customer_id: "cus_1").call).to be(false)
  end
end
