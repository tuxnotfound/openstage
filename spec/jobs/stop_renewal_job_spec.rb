require "rails_helper"

RSpec.describe StopRenewalJob, type: :job do
  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  it "stops the plan through the service" do
    service = instance_double(Billing::StopRenewalService, call!: true)
    expect(Billing::StopRenewalService).to receive(:new).with(subscription_id: "sub_123").and_return(service)

    described_class.perform_now("sub_123")
  end

  it "retries when Stripe is unreachable" do
    allow(StripeGateway).to receive(:cancel_at_period_end).and_raise(ApplicationGateway::ConnectionFailed)

    expect { described_class.perform_now("sub_123") }.to have_enqueued_job(described_class).with("sub_123")
  end
end
