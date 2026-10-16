require "rails_helper"

RSpec.describe WeeklyMailer do
  let(:builder) { create(:user, username: "maker", display_name: "Mia Maker", email: "mia@example.com") }

  before do
    create(:entry, user: builder, entry_type: "milestone", source: "manual", title: "Opened the beta", occurred_at: 1.day.ago)
    create(:entry, user: builder, title: "Add billing", repo_name: "maker/app", occurred_at: 1.day.ago)
    create(:entry, user: builder, title: "Fix login", repo_name: "maker/app", occurred_at: 2.days.ago)
    create(:entry, user: builder, title: "Secret plan", repo_name: "maker/app", occurred_at: 1.day.ago,
                   visibility: :private_entry)
    create(:entry, user: builder, title: "Excluded repo work", repo_name: "maker/hidden", occurred_at: 1.day.ago,
                   hidden: true)
  end

  describe "#week_ready" do
    let(:mail) { described_class.week_ready(builder) }

    it "sends the builder their week with one link to the picker" do
      expect(mail.to).to eq([ "mia@example.com" ])
      expect(mail.subject).to eq("Your week is ready to review")
      body = mail.text_part.body.to_s
      expect(body).to include("Opened the beta", "Add billing", "Fix login")
      expect(body).to include("https://openstage.dev/recap?from=weekly")
      expect(mail.html_part.body.to_s).to include("https://openstage.dev/recap?from=weekly")
    end

    it "carries a stop link that works in one click" do
      expect(mail.header["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
      expect(mail.header["List-Unsubscribe"].value).to include("/weekly_email/unsubscribe?token=")
      expect(mail.text_part.body.to_s).to include("/weekly_email/unsubscribe?token=")
    end
  end

  describe "#digest" do
    let(:subscription) { builder.subscriptions.create!(email: "reader@example.com", confirmed_at: 1.week.ago) }
    let(:mail) { described_class.digest(subscription) }

    it "sends the subscriber the builder's public week" do
      expect(mail.to).to eq([ "reader@example.com" ])
      expect(mail.subject).to eq("What Mia Maker shipped this week")
      body = mail.text_part.body.to_s
      expect(body).to include("Opened the beta", "Add billing", "Fix login")
      expect(body).to include("https://openstage.dev/maker?ref=digest")
      expect(body).to include("https://openstage.dev/?ref=digest")
    end

    it "never carries a private or hidden entry" do
      [ mail.text_part.body.to_s, mail.html_part.body.to_s ].each do |body|
        expect(body).not_to include("Secret plan")
        expect(body).not_to include("Excluded repo work")
      end
    end

    it "unsubscribes in one click" do
      expect(mail.header["List-Unsubscribe"].value).to include("/subscriptions/#{subscription.token}/unsubscribe")
      expect(mail.header["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
    end
  end
end
