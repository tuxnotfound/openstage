require "rails_helper"

RSpec.describe "Checkout", type: :request do
  let(:user) { create(:user) }

  around do |example|
    ENV["STRIPE_MONTHLY_PRICE_ID"] = "price_monthly"
    example.run
  ensure
    ENV.delete("STRIPE_MONTHLY_PRICE_ID")
  end

  it "starts a $7 monthly subscription on Stripe's page" do
    allow(StripeGateway).to receive(:checkout_url).and_return("https://checkout.stripe.com/c/pay/cs_test")
    sign_in_as(user)

    post "/checkout"

    expect(response).to redirect_to("https://checkout.stripe.com/c/pay/cs_test")
    expect(StripeGateway).to have_received(:checkout_url)
      .with(price: "price_monthly", user_id: user.id, success_url: "http://www.example.com/dashboard?pro=activated",
            cancel_url: "http://www.example.com/dashboard")
  end

  it "offers no lifetime deal, even to a page cached from before" do
    allow(StripeGateway).to receive(:checkout_url).and_return("https://checkout.stripe.com/c/pay/cs_test")
    sign_in_as(user)

    post "/checkout", params: { plan: "lifetime" }

    expect(StripeGateway).to have_received(:checkout_url).with(hash_including(price: "price_monthly"))
  end

  it "says so when Stripe does not answer, and reports it" do
    allow(StripeGateway).to receive(:checkout_url).and_raise(ApplicationGateway::ConnectionFailed, "timeout")
    allow(Rails.error).to receive(:report)
    sign_in_as(user)

    post "/checkout", headers: { "HTTP_REFERER" => "http://www.example.com/pricing" }

    expect(response).to redirect_to("http://www.example.com/pricing")
    expect(flash[:alert]).to eq("Stripe did not answer. Try again in a minute.")
    expect(Rails.error).to have_received(:report)
  end

  it "opens the billing page for a builder with a Stripe account, and refuses one without" do
    allow(StripeGateway).to receive(:billing_portal_url).and_return("https://billing.stripe.com/p/session/bps_1")
    sign_in_as(user)

    get "/billing"
    expect(response).to redirect_to(settings_path)

    user.update!(stripe_customer_id: "cus_1")
    get "/billing"
    expect(response).to redirect_to("https://billing.stripe.com/p/session/bps_1")
  end

  it "sends a visitor to sign in" do
    post "/checkout"

    expect(response).to redirect_to(root_path)
  end
end
