require "rails_helper"

RSpec.describe SetRenewalJob, type: :job do
  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  it "stops the plan through the service" do
    service = instance_double(Billing::SetRenewalService, call!: true)
    expect(Billing::SetRenewalService).to receive(:new).with(subscription_id: "sub_123", renew: false).and_return(service)

    described_class.perform_now("sub_123", false)
  end

  it "retries when Stripe is unreachable" do
    allow(StripeGateway).to receive(:set_renewal).and_raise(ApplicationGateway::ConnectionFailed)

    expect { described_class.perform_now("sub_123", false) }.to have_enqueued_job(described_class).with("sub_123", false)
  end
end
