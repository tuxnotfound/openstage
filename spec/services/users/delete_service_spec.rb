require "rails_helper"

RSpec.describe Users::DeleteService do
  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  it "takes the account offline and stops its monthly plan from renewing" do
    user = create(:user, pro: true, stripe_subscription_id: "sub_123")

    expect { described_class.new(user: user).call! }.to have_enqueued_job(SetRenewalJob).with("sub_123", false)
    expect(user.reload).to be_deleted
  end

  it "enqueues nothing for an account without a plan" do
    user = create(:user)

    expect { described_class.new(user: user).call! }.not_to have_enqueued_job(SetRenewalJob)
    expect(user.reload).to be_deleted
  end

  it "requires a user" do
    expect(described_class.new(user: nil).call).to be(false)
  end
end
