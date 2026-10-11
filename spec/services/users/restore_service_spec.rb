require "rails_helper"

RSpec.describe Users::RestoreService do
  around do |example|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  it "brings the account back and lets its monthly plan renew again" do
    user = create(:user, deleted_at: 3.days.ago, pro: true, stripe_subscription_id: "sub_123")

    expect { described_class.new(user: user).call! }.to have_enqueued_job(SetRenewalJob).with("sub_123", true)
    expect(user.reload).not_to be_deleted
  end

  it "touches no billing for an account without a plan" do
    user = create(:user, deleted_at: 3.days.ago)

    expect { described_class.new(user: user).call! }.not_to have_enqueued_job(SetRenewalJob)
    expect(user.reload).not_to be_deleted
  end

  it "refuses an account that is not deleted" do
    expect(described_class.new(user: create(:user)).call).to be(false)
  end

  it "requires a user" do
    expect(described_class.new(user: nil).call).to be(false)
  end
end
