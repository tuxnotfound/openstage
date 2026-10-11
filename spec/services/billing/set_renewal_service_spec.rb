require "rails_helper"

RSpec.describe Billing::SetRenewalService do
  around do |example|
    key = Stripe.api_key
    Stripe.api_key = "sk_test_openstage"
    example.run
  ensure
    Stripe.api_key = key
  end

  let(:endpoint) { "https://api.stripe.com/v1/subscriptions/sub_123" }

  it "stops the plan at the end of the period already paid for" do
    stub = stub_request(:post, endpoint).with(body: { "cancel_at_period_end" => "true" })
                                        .to_return(status: 200, body: { id: "sub_123", object: "subscription" }.to_json)

    expect(described_class.new(subscription_id: "sub_123", renew: false).call).to be(true)
    expect(stub).to have_been_requested
  end

  it "lets the plan renew again" do
    stub = stub_request(:post, endpoint).with(body: { "cancel_at_period_end" => "false" })
                                        .to_return(status: 200, body: { id: "sub_123", object: "subscription" }.to_json)

    expect(described_class.new(subscription_id: "sub_123", renew: true).call).to be(true)
    expect(stub).to have_been_requested
  end

  it "is done when Stripe no longer has the plan" do
    stub_request(:post, endpoint).to_return(status: 404, body: { error: { type: "invalid_request_error", code: "resource_missing" } }.to_json)

    expect(described_class.new(subscription_id: "sub_123", renew: false).call).to be(true)
  end

  it "raises a gateway error when Stripe fails, so the job retries" do
    stub_request(:post, endpoint).to_return(status: 500, body: { error: { type: "api_error" } }.to_json)

    expect { described_class.new(subscription_id: "sub_123", renew: false).call }.to raise_error(ApplicationGateway::ServerError)
  end

  it "requires a subscription id and a direction" do
    expect(described_class.new(subscription_id: nil, renew: false).call).to be(false)
    expect(described_class.new(subscription_id: "sub_123", renew: nil).call).to be(false)
  end
end
