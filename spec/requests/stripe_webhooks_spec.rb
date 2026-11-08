require "rails_helper"

RSpec.describe "Stripe's webhook", type: :request do
  let(:user) { create(:user, pro: false) }
  let(:secret) { "whsec_test" }

  around do |example|
    was = ENV["STRIPE_WEBHOOK_SECRET"]
    ENV["STRIPE_WEBHOOK_SECRET"] = secret
    example.run
  ensure
    ENV["STRIPE_WEBHOOK_SECRET"] = was
  end

  def deliver(payload, signed_with: secret)
    time = Time.current.to_i
    signature = Stripe::Webhook::Signature.compute_signature(Time.at(time), payload, signed_with)
    post "/webhooks/stripe", params: payload, headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "t=#{time},v1=#{signature}" }
  end

  def completed
    { id: "evt_1", object: "event", type: "checkout.session.completed",
      data: { object: { id: "cs_1", object: "checkout.session", metadata: { user_id: user.id.to_s }, customer: "cus_1", subscription: "sub_1" } } }.to_json
  end

  it "makes the builder of a finished checkout Pro" do
    deliver(completed)

    expect(response).to have_http_status(:ok)
    expect(user.reload).to have_attributes(pro: true, stripe_customer_id: "cus_1", stripe_subscription_id: "sub_1")
  end

  it "keeps the day the plan began when the return from Stripe's page came first" do
    began = 1.minute.ago.change(usec: 0)
    user.update!(pro: true, stripe_customer_id: "cus_1", stripe_subscription_id: "sub_1", pro_since: began)

    deliver(completed)

    expect(user.reload.pro_since).to eq(began)
  end

  it "refuses a delivery Stripe did not sign" do
    deliver(completed, signed_with: "whsec_other")

    expect(response).to have_http_status(:bad_request)
    expect(user.reload).not_to be_pro
  end
end
