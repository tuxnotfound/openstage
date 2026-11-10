require "rails_helper"

RSpec.describe PageViews::RecordService do
  let(:user) { create(:user) }
  let(:browser) { "Mozilla/5.0 (Macintosh) Safari/605.1.15" }

  def record(ticket: PageViewTicket.issue(user: user, referrer: "x.com"), **overrides)
    described_class.new(ticket: ticket, ip: "203.0.113.7", user_agent: browser, country: "PT", **overrides)
  end

  it "records a view of the builder's stage, the IP hashed with the day and a key" do
    service = record

    expect(service.call).to be(true)
    expect(service.view).to have_attributes(user: user, referrer: "x.com", country: "PT", ip_hash: VisitorHash.of("203.0.113.7"))
    expect(user.profile_views.count).to eq(1)
  end

  it "records a project page's view by the project's repo" do
    record(ticket: PageViewTicket.issue(user: user, referrer: nil, repo_name: "builder/side.app")).call!

    expect(user.project_views.sole).to have_attributes(repo_name: "builder/side.app", referrer: nil)
    expect(user.profile_views.count).to eq(0)
  end

  it "keeps a blank country as none" do
    expect(record(country: "").tap(&:call!).view.country).to be_nil
  end

  it "refuses a request without a ticket" do
    service = record(ticket: nil)

    expect(service.call).to be(false)
    expect(service.errors[:ticket]).to include("can't be blank")
  end

  it "refuses a request without an IP" do
    service = record(ip: nil)

    expect(service.call).to be(false)
    expect(service.errors[:ip]).to include("can't be blank")
  end

  it "refuses a bot's" do
    service = record(user_agent: "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)")

    expect(service.call).to be(false)
    expect(service.errors[:user_agent]).to include("is a bot's")
  end

  it "refuses a ticket Openstage did not issue" do
    forged = PageViewTicket.issue(user: user, referrer: nil).then { |ticket| ticket.sub(/.\z/) { |last| last == "a" ? "b" : "a" } }
    service = record(ticket: forged)

    expect(service.call).to be(false)
    expect(service.errors[:ticket]).to include("is not one Openstage issued, or it expired")
  end

  it "refuses a ticket that expired" do
    service = record

    travel(PageViewTicket::LIFETIME + 1.minute) { expect(service.call).to be(false) }
    expect(service.errors[:ticket]).to include("is not one Openstage issued, or it expired")
  end

  it "refuses a ticket for an account deleted since" do
    service = record
    user.update!(deleted_at: Time.current)

    expect(service.call).to be(false)
    expect(ProfileView.count).to eq(0)
  end
end
