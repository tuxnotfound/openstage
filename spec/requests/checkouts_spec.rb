require "rails_helper"

RSpec.describe "Checkout", type: :request do
  let(:user) { create(:user) }
  let(:checkout) { instance_double(Stripe::Checkout::Session, url: "https://checkout.stripe.com/c/pay/cs_test") }

  around do |example|
    ENV["STRIPE_MONTHLY_PRICE_ID"] = "price_monthly"
    example.run
  ensure
    ENV.delete("STRIPE_MONTHLY_PRICE_ID")
  end

  it "starts a $7 monthly subscription on Stripe's page" do
    allow(Stripe::Checkout::Session).to receive(:create).and_return(checkout)
    sign_in_as(user)

    post "/checkout"

    expect(response).to redirect_to("https://checkout.stripe.com/c/pay/cs_test")
    expect(Stripe::Checkout::Session).to have_received(:create).with(
      hash_including(mode: "subscription", line_items: [ { price: "price_monthly", quantity: 1 } ], metadata: { user_id: user.id })
    )
  end

  it "offers no lifetime deal, even to a page cached from before" do
    allow(Stripe::Checkout::Session).to receive(:create).and_return(checkout)
    sign_in_as(user)

    post "/checkout", params: { plan: "lifetime" }

    expect(Stripe::Checkout::Session).to have_received(:create).with(hash_including(mode: "subscription"))
  end

  it "sends a visitor to sign in" do
    post "/checkout"

    expect(response).to redirect_to(root_path)
  end
end
