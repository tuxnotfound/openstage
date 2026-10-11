require "rails_helper"

RSpec.describe PurgeDeletedUsersJob, type: :job do
  it "purges the accounts past their 30 days" do
    gone = create(:user, deleted_at: 31.days.ago)

    described_class.perform_now

    expect(User.exists?(gone.id)).to be(false)
  end
end
