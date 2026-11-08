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

  describe ".checkout_session" do
    it "reads who started a checkout, whether it is paid, and its subscription now" do
      stub_request(:get, "https://api.stripe.com/v1/checkout/sessions/cs_1?expand%5B0%5D=subscription")
        .to_return(status: 200, headers: json, body: { id: "cs_1", object: "checkout.session", metadata: { user_id: "7" }, payment_status: "paid",
                                                       customer: "cus_1", subscription: { id: "sub_1", object: "subscription", status: "active" } }.to_json)

      expect(described_class.checkout_session("cs_1"))
        .to eq(user_id: "7", paid: true, customer: "cus_1", subscription: "sub_1", subscription_status: "active")
    end

    it "raises NotFound for a checkout Stripe does not know" do
      stub_request(:get, %r{/v1/checkout/sessions/cs_gone})
        .to_return(status: 404, headers: json, body: { error: { message: "No such session", type: "invalid_request_error" } }.to_json)

      expect { described_class.checkout_session("cs_gone") }.to raise_error(ApplicationGateway::NotFound)
    end
  end

  describe ".products" do
    it "reads a page of the builder's products with their own key, as hashes" do
      stub_request(:get, "https://api.stripe.com/v1/products?limit=1")
        .with(headers: { "Authorization" => "Bearer rk_test_builder" })
        .to_return(status: 200, headers: json, body: { object: "list", has_more: true, url: "/v1/products",
                                                       data: [ { id: "prod_1", object: "product", name: "Shipnote Pro" } ] }.to_json)

      page = described_class.products("rk_test_builder", limit: 1)

      expect(page).to eq(data: [ { id: "prod_1", object: "product", name: "Shipnote Pro" } ], has_more: true)
    end

    it "turns a read the key lacks into Unauthorized, with Stripe's 403" do
      stub_request(:get, "https://api.stripe.com/v1/products?limit=1")
        .to_return(status: 403, headers: json, body: { error: { message: "The provided key does not have the required permissions.",
                                                                type: "invalid_request_error" } }.to_json)

      expect { described_class.products("rk_test_builder", limit: 1) }
        .to raise_error(ApplicationGateway::Unauthorized) { |error| expect(error.status).to eq(403) }
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
