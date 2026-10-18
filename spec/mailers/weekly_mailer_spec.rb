require "rails_helper"

RSpec.describe WeeklyMailer do
  # A Friday send: Week 43 runs Mon Oct 19 to today.
  before { travel_to Time.utc(2026, 10, 23, 13) }

  let(:builder) { create(:user, username: "maker", display_name: "Mia Maker", email: "mia@example.com") }

  def week_of_work
    create(:entry, user: builder, entry_type: "milestone", source: "manual", title: "Opened the beta", occurred_at: 2.days.ago)
    create(:entry, user: builder, entry_type: "note", source: "manual", title: "Wrote about pricing", occurred_at: 1.day.ago)
    create(:entry, user: builder, title: "Add billing", repo_name: "maker/app", occurred_at: 1.day.ago)
    create(:entry, user: builder, title: "Fix login", repo_name: "maker/app", occurred_at: 2.days.ago)
    create(:entry, user: builder, entry_type: "milestone", source: "manual", title: "Secret plan", occurred_at: 1.day.ago,
                   visibility: :private_entry)
    create(:entry, user: builder, title: "Excluded repo work", repo_name: "maker/hidden", occurred_at: 1.day.ago,
                   hidden: true)
  end

  describe "#week_ready" do
    let(:mail) { described_class.week_ready(builder) }

    before { week_of_work }

    it "sends the builder the Week view of their page, with the counters" do
      expect(mail.to).to eq([ "mia@example.com" ])
      expect(mail.subject).to eq("Your week is ready to review")
      expect(mail.text_part.body.to_s).to include("Week 43 · Oct 19–25 · so far")
      expect(mail.text_part.body.to_s).to include("1 shipped · 1 published · 2 commits · 2 active days · 1 project")
    end

    it "lists what was shipped and published, numbered, and never a commit" do
      text = mail.text_part.body.to_s
      expect(text).to include("1. ● Opened the beta (Oct 21)", "2. ○ Wrote about pricing (Oct 22)")
      [ text, mail.html_part.body.to_s ].each do |body|
        expect(body).not_to include("Add billing")
        expect(body).not_to include("Fix login")
      end
    end

    it "draws the chart as table cells, one column per day so far" do
      html = mail.html_part.body.to_s
      expect(html).to include("Mon 19", "Fri 23")
      expect(html).not_to include("Sat 24")
      expect(html).not_to include("<svg")
      expect(html).to include("background: #{ProgressChart::Palette.project_color(0)}")
    end

    it "puts the one link to the picker before the list" do
      html = mail.html_part.body.to_s
      expect(html).to include("https://openstage.dev/recap?from=weekly")
      expect(html.index("https://openstage.dev/recap?from=weekly")).to be < html.index("Opened the beta")
      expect(mail.text_part.body.to_s).to include("Pick what to share: https://openstage.dev/recap?from=weekly")
    end

    it "carries a stop link that works in one click" do
      expect(mail.header["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
      expect(mail.header["List-Unsubscribe"].value).to include("/weekly_email/unsubscribe?token=")
      expect(mail.text_part.body.to_s).to include("/weekly_email/unsubscribe?token=")
    end
  end

  describe "#week_ready on a week of commits only" do
    it "says nothing was shipped or published yet and offers to log an entry" do
      3.times { |i| create(:entry, user: builder, title: "Commit #{i}", repo_name: "maker/app", occurred_at: 1.day.ago) }
      mail = described_class.week_ready(builder)

      expect(mail.text_part.body.to_s).to include("Nothing shipped or published this week yet.", "Log an entry: https://openstage.dev/dashboard")
      expect(mail.html_part.body.to_s).to include("https://openstage.dev/dashboard")
    end
  end

  describe "#digest" do
    let(:subscription) { builder.subscriptions.create!(email: "reader@example.com", confirmed_at: 1.week.ago) }
    let(:mail) { described_class.digest(subscription) }

    before { week_of_work }

    it "sends the subscriber the builder's public week, linked to the same view on the page" do
      expect(mail.to).to eq([ "reader@example.com" ])
      expect(mail.subject).to eq("Mia Maker's week on Openstage")
      text = mail.text_part.body.to_s
      expect(text).to include("1. ● Opened the beta (Oct 21)", "2. ○ Wrote about pricing (Oct 22)")
      expect(text).to include("https://openstage.dev/maker?range=week&ref=digest")
      expect(text).to include("https://openstage.dev/?ref=digest")
      expect(text).not_to include("Log an entry")
    end

    it "never carries a private or hidden entry, nor counts one" do
      [ mail.text_part.body.to_s, mail.html_part.body.to_s ].each do |body|
        expect(body).not_to include("Secret plan")
        expect(body).not_to include("Excluded repo work")
      end
      expect(mail.text_part.body.to_s).to include("1 shipped · 1 published · 2 commits")
    end

    it "unsubscribes in one click" do
      expect(mail.header["List-Unsubscribe"].value).to include("/subscriptions/#{subscription.token}/unsubscribe")
      expect(mail.header["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
    end
  end
end
