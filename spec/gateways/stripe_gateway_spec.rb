require "rails_helper"

RSpec.describe StripeGateway do
  let(:json) { { "Content-Type" => "application/json" } }

  around do |example|
    key = Stripe.api_key
    Stripe.api_key = "sk_test_gateway"
    example.run
  ensure
    Stripe.api_key = key
  end

  describe ".checkout_url" do
    it "starts a subscription to the price, for the builder, and returns Stripe's page" do
      stub = stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
             .with(body: hash_including("mode" => "subscription", "line_items" => [ { "price" => "price_monthly", "quantity" => "1" } ],
                                        "metadata" => { "user_id" => "7" }, "success_url" => "https://openstage.dev/dashboard?pro=activated"))
             .to_return(status: 200, headers: json, body: { id: "cs_test", object: "checkout.session", url: "https://checkout.stripe.com/c/pay/cs_test" }.to_json)

      url = described_class.checkout_url(price: "price_monthly", user_id: 7,
                                         success_url: "https://openstage.dev/dashboard?pro=activated", cancel_url: "https://openstage.dev/dashboard")

      expect(url).to eq("https://checkout.stripe.com/c/pay/cs_test")
      expect(stub).to have_been_requested
    end

    it "turns Stripe's refusal into the gateway's own error" do
      stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
        .to_return(status: 400, headers: json, body: { error: { message: "No such price: 'price_gone'", type: "invalid_request_error" } }.to_json)

      expect { described_class.checkout_url(price: "price_gone", user_id: 7, success_url: "https://a.example", cancel_url: "https://a.example") }
        .to raise_error(ApplicationGateway::ClientError) { |error| expect(error.status).to eq(400) }
    end
  end

  describe ".billing_portal_url" do
    it "opens the customer's billing page and returns its address" do
      stub_request(:post, "https://api.stripe.com/v1/billing_portal/sessions")
        .with(body: { "customer" => "cus_1", "return_url" => "https://openstage.dev/settings" })
        .to_return(status: 200, headers: json, body: { id: "bps_1", object: "billing_portal.session", url: "https://billing.stripe.com/p/session/bps_1" }.to_json)

      expect(described_class.billing_portal_url(customer: "cus_1", return_url: "https://openstage.dev/settings"))
        .to eq("https://billing.stripe.com/p/session/bps_1")
    end
  end
end
