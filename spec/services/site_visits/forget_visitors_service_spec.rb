require "rails_helper"

RSpec.describe SiteVisits::ForgetVisitorsService do
  let(:repo) { create(:github_repo) }

  before { travel_to Time.utc(2026, 10, 26, 3) }

  it "deletes the hashes of days over everywhere, and keeps the totals" do
    old = repo.site_visitors.create!(day: Date.new(2026, 10, 24), visitor_hash: "a")
    behind = repo.site_visitors.create!(day: Date.new(2026, 10, 25), visitor_hash: "b")
    repo.site_visit_days.create!(day: Date.new(2026, 10, 24), visits: 3, visitors: 1)

    service = described_class.new.tap(&:call!)

    expect(service.forgotten).to eq(1)
    expect(SiteVisitor.exists?(old.id)).to be(false)
    expect(SiteVisitor.exists?(behind.id)).to be(true)
    expect(repo.site_visit_days.count).to eq(1)
  end

  it "runs from its daily job" do
    repo.site_visitors.create!(day: Date.new(2026, 10, 1), visitor_hash: "a")

    expect { ForgetSiteVisitorsJob.perform_now }.to change(SiteVisitor, :count).by(-1)
  end
end
