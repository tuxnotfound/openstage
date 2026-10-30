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
      expect(mail.subject).to eq("Your week on Openstage")
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

    it "draws the page's chart as a picture carried inline, since mail shows no SVG" do
      image = mail.attachments[ProgressChart::EmailImage::FILE]
      html = mail.html_part.body.to_s

      expect(image).to be_inline
      expect(image.mime_type).to eq("image/png")
      expect(image.body.decoded.byteslice(0, 8)).to eq("\x89PNG\r\n\x1A\n".b)
      expect(html).to include(%(src="#{image.url}"), "alt=\"Commits per day by project this week: app 2\"")
      expect(html).not_to include("<svg")
    end

    it "puts the one link, to their page, after the list, so the chart runs straight into it" do
      html = mail.html_part.body.to_s
      text = mail.text_part.body.to_s
      url = "https://openstage.dev/maker?range=30d&ref=weekly"
      expect(html.index(url.sub("&", "&amp;"))).to be > html.index("Wrote about pricing")
      expect(text.index(url)).to be > text.index("Wrote about pricing")
      expect(text).to include("See your page: #{url}")
    end

    it "draws the app's look: the wordmark, then grey panels with soft corners" do
      html = mail.html_part.body.to_s
      expect(html.index(">openstage</td>")).to be < html.index("Week 43")
      expect(html.scan("background: #{MailHelper::FILL}; border-radius: 22px").size).to eq(2)
      expect(html).not_to include("fonts.googleapis.com")
    end

    it "carries a stop link that works in one click" do
      expect(mail.header["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
      expect(mail.header["List-Unsubscribe"].value).to include("/weekly_email/unsubscribe?token=")
      expect(mail.text_part.body.to_s).to include("/weekly_email/unsubscribe?token=")
    end
  end

  describe "#week_ready with entries the builder hid from the lists" do
    it "counts them in the counters and the chart, and lists none of them" do
      week_of_work
      create(:github_repo, user: builder, full_name: "maker/app", name: "app")
      create(:entry, user: builder, title: "Hidden fix", repo_name: "maker/app", occurred_at: 1.day.ago, hidden: true)
      create(:entry, user: builder, entry_type: "note", source: "manual", title: "Hidden note", occurred_at: 1.day.ago, hidden: true)
      mail = described_class.week_ready(builder)

      expect(mail.text_part.body.to_s).to include("1 shipped · 2 published · 3 commits · 2 active days · 1 project")
      expect(mail.html_part.body.to_s).to include("alt=\"Commits per day by project this week: app 3\"")
      [ mail.text_part.body.to_s, mail.html_part.body.to_s ].each { |body| expect(body).not_to include("Hidden note") }
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

  describe "#week_ready on a week whose commits are all on projects past the tenth" do
    it "says why it has no chart, never that the week had no commits" do
      10.times { |i| 4.times { create(:entry, user: builder, repo_name: "maker/old#{i}", occurred_at: 40.days.ago) } }
      3.times { create(:entry, user: builder, repo_name: "maker/new", occurred_at: 1.day.ago) }
      html = described_class.week_ready(builder).html_part.body.to_s

      expect(html).to include("Only projects past the tenth have commits this week, and the chart draws ten projects at most.")
      expect(html).not_to include("No commits", "<img")
    end
  end

  describe "#week_ready on a week with no commits" do
    it "says so where the chart would be" do
      3.times { create(:entry, user: builder, entry_type: "milestone", source: "manual", title: "Launched", occurred_at: 1.day.ago) }

      expect(described_class.week_ready(builder).html_part.body.to_s).to include("No commits this week yet.")
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
      expect(text).to include("https://openstage.dev/maker?range=30d&ref=digest")
      expect(text).to include("https://openstage.dev/?ref=digest")
      expect(text).not_to include("Log an entry")
    end

    it "leads with the builder's face and name, which the builder's own email does not" do
      html = mail.html_part.body.to_s
      expect(html).to include(builder.avatar_url, "openstage.dev/maker")
      expect(html.index(builder.avatar_url)).to be < html.index("Week 43")
      expect(described_class.week_ready(builder).html_part.body.to_s).not_to include(builder.avatar_url)
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

    context "for one project's follower" do
      let(:repo) { create(:github_repo, user: builder, name: "app", full_name: "maker/app") }
      let(:subscription) { builder.subscriptions.create!(email: "fan@example.com", github_repo: repo, confirmed_at: 1.week.ago) }

      it "sends that project's week only, linked to its page" do
        create(:entry, user: builder, title: "Other project work", repo_name: "maker/other", occurred_at: 1.day.ago)

        expect(mail.subject).to eq("app this week, by Mia Maker")
        text = mail.text_part.body.to_s
        expect(text).to include("2 commits", "https://openstage.dev/maker/app?range=30d&ref=digest", "updates on openstage.dev/maker/app")
        expect(text).not_to include("Opened the beta", "Other project work")
      end

      it "draws a project past the tenth for its follower in ink, which the builder's whole week leaves out" do
        10.times { |i| 3.times { create(:entry, user: builder, repo_name: "maker/p#{i}", occurred_at: 1.day.ago) } }
        chip = %r{background: #0E0F12;"></span> app <strong}

        expect(mail.attachments[ProgressChart::EmailImage::FILE]).to be_present
        expect(mail.html_part.body.to_s).to match(chip)
        expect(described_class.week_ready(builder).html_part.body.to_s).not_to match(%r{</span> app <strong})
      end
    end
  end
end
