require "rails_helper"

RSpec.describe ReadRevenueFanoutJob do
  it "reads every connected account, except a deleted builder's" do
    kept = create(:user).revenue_accounts.create!(provider: "stripe", api_key: "rk_test_a")
    create(:user, deleted_at: Time.current).revenue_accounts.create!(provider: "stripe", api_key: "rk_test_b")

    expect { described_class.perform_now }.to have_enqueued_job(ReadRevenueJob).with(kept.id).exactly(:once)
  end
end
