require "rails_helper"

RSpec.describe WeeklyEmails::TestService do
  before { travel_to Time.utc(2026, 10, 23, 13) }

  let(:owner) { create(:user, username: "owner", display_name: "Owner", email: "me@example.com", weekly_email_sent_at: nil) }

  it "sends both weekly emails to the owner, marked as a test" do
    create(:entry, user: owner, title: "Add billing", repo_name: "owner/app", occurred_at: 1.day.ago)

    expect { described_class.new(user: owner).call! }.to change { ActionMailer::Base.deliveries.count }.by(2)

    mails = ActionMailer::Base.deliveries.last(2)
    expect(mails.map(&:to)).to all(eq([ "me@example.com" ]))
    expect(mails.map(&:subject)).to eq([ "[Test] Your week is ready to review", "[Test] Owner's week on Openstage" ])
  end

  it "sends on a quiet week, and claims nothing and saves no subscription" do
    expect { described_class.new(user: owner).call! }.not_to change(Subscription, :count)
    expect(owner.reload.weekly_email_sent_at).to be_nil
  end

  it "refuses when the owner has no address" do
    owner.update!(email: nil)
    service = described_class.new(user: owner)

    expect(service.call).to be(false)
    expect(service.errors.full_messages.to_sentence).to match(/no email/i)
  end

  it "requires a user" do
    expect(described_class.new(user: nil).call).to be(false)
  end
end
