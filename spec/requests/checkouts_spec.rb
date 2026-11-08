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
      .with(price: "price_monthly", user_id: user.id, success_url: "http://www.example.com/checkout/confirm?session_id={CHECKOUT_SESSION_ID}",
            cancel_url: "http://www.example.com/dashboard")
  end

  describe "the return from Stripe's page" do
    let(:checkout) { { user_id: user.id.to_s, paid: true, customer: "cus_1", subscription: "sub_1", subscription_status: "active" } }

    before { sign_in_as(user) }

    it "makes the builder Pro and says so" do
      allow(StripeGateway).to receive(:checkout_session).with("cs_1").and_return(checkout)

      get "/checkout/confirm", params: { session_id: "cs_1" }

      expect(response).to redirect_to("/dashboard?pro=activated")
      expect(user.reload).to be_pro
      follow_redirect!
      expect(response.body).to include("You're Pro!")
    end

    it "tells a builder Stripe has not confirmed not to pay again, and leaves them on Free" do
      allow(StripeGateway).to receive(:checkout_session).and_return(checkout.merge(paid: false))

      get "/checkout/confirm", params: { session_id: "cs_1" }

      expect(flash[:alert]).to eq(Billing::ConfirmCheckoutService::NOT_CONFIRMED)
      expect(user.reload).not_to be_pro
    end

    it "says the same when Stripe does not answer, and reports it" do
      allow(StripeGateway).to receive(:checkout_session).and_raise(ApplicationGateway::ConnectionFailed, "timeout")
      allow(Rails.error).to receive(:report)

      get "/checkout/confirm", params: { session_id: "cs_1" }

      expect(response).to redirect_to("/dashboard")
      expect(flash[:alert]).to eq(Billing::ConfirmCheckoutService::NOT_CONFIRMED)
      expect(Rails.error).to have_received(:report)
    end
  end

  it "never says You're Pro to a builder who is not, whatever the address says" do
    sign_in_as(user)

    get "/dashboard", params: { pro: "activated" }

    expect(response.body).not_to include("You're Pro!")
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
