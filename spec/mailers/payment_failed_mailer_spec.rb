require "rails_helper"

RSpec.describe PaymentFailedMailer, type: :mailer do
  describe "#notify" do
    it "sends to the address captured at sign-in" do
      user = create(:user, email: "builder@example.com")
      mail = described_class.notify(user)

      expect(mail.to).to eq([ "builder@example.com" ])
      expect(mail.subject).to match(/payment failed/i)
      expect(mail.from).not_to include("from@example.com")
    end

    it "sets a Reply-To that can actually receive, since the domain has no MX" do
      mail = described_class.notify(create(:user, email: "builder@example.com"))

      expect(mail.reply_to).to be_present
      expect(mail.reply_to.first).not_to include("openstage.dev")
    end

    it "quietly does nothing for users who predate email capture" do
      user = create(:user, email: nil)

      expect { described_class.notify(user).deliver_now }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end
end
