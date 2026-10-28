require "rails_helper"

RSpec.describe SiteVisits::RecordService do
  let(:user) { create(:user, pro: true, time_zone: "America/New_York") }
  let!(:repo) { create(:github_repo, user: user, homepage: "https://shipnote.app", site_source: "script", site_token: "os_abc123") }
  let(:browser) { "Mozilla/5.0 (Macintosh) Safari/605.1.15" }

  before { travel_to Time.utc(2026, 10, 26, 2) }

  def record(**overrides)
    described_class.new(token: "os_abc123", url: "https://shipnote.app/", ip: "203.0.113.7", user_agent: browser, **overrides)
  end

  it "counts views and visitors on the builder's day, a visitor once" do
    2.times { record.call! }
    record(ip: "203.0.113.8").call!

    expect(repo.site_visit_days.sole).to have_attributes(day: Date.new(2026, 10, 25), visits: 3, visitors: 2)
    expect(repo.reload.site_first_visit_at).to eq(Time.current)
  end

  it "keeps a visitor as a hash that changes with the day, never the IP" do
    record.call!
    travel 1.day
    record.call!

    hashes = SiteVisitor.pluck(:visitor_hash)
    expect(hashes.uniq.size).to eq(2)
    expect(hashes.join).not_to include("203.0.113.7")
  end

  it "takes the bare domain and www. as one site, any case" do
    expect(record(url: "https://WWW.shipnote.app/blog", origin: "https://shipnote.app").call).to be(true)
  end

  it "stops counting one visitor past the daily limit" do
    stub_const("#{described_class}::DAILY_LIMIT", 2)
    3.times { record.call! }

    expect(repo.site_visit_days.sole.visits).to eq(2)
  end

  it "refuses a bot" do
    service = record(user_agent: "Googlebot/2.1")

    expect(service.call).to be(false)
    expect(service.errors[:user_agent]).to be_present
  end

  it "refuses a page or an Origin that is not the project's website" do
    expect(record(url: "https://copycat.example/").call).to be(false)
    expect(record(origin: "https://copycat.example").call).to be(false)
    expect(SiteVisitDay.count).to eq(0)
  end

  it "refuses a project without a website, without the script, or of a deleted builder" do
    repo.update!(homepage: nil)
    expect(record.call).to be(false)

    repo.update!(homepage: "https://shipnote.app", site_source: nil)
    expect(record.call).to be(false)

    repo.update!(site_source: "script")
    user.soft_delete!
    expect(record.call).to be(false)
  end

  it "takes nothing from a project paused on Free, keeps its totals, and counts the one set up first" do
    user.update!(pro: false)
    repo.update!(site_set_up_at: 10.days.ago)
    paused = create(:github_repo, user: user, homepage: "https://tidepool.dev", site_source: "script", site_token: "os_other", site_set_up_at: 3.days.ago)
    paused.site_visit_days.create!(day: Date.new(2026, 10, 1), visits: 50, visitors: 40)
    service = record(token: "os_other", url: "https://tidepool.dev/")

    expect(service.call).to be(false)
    expect(service.errors[:token]).to eq([ "names no project that counts visits" ])
    expect([ paused.site_visitors.count, paused.site_visit_days.sole.visits, paused.reload.site_first_visit_at ]).to eq([ 0, 50, nil ])
    expect(record.call).to be(true)
  end
end
