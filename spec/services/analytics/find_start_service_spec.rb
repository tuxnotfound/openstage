require "rails_helper"

RSpec.describe Analytics::FindStartService do
  let(:user) { create(:user, time_zone: "Europe/Lisbon") }

  before { travel_to Time.utc(2026, 10, 24, 12) }

  def first_day(pages)
    described_class.new(user: user, pages: pages).tap(&:call!).first_day
  end

  it "finds the first day the pages picked had a visit, a follower or a click, in the builder's zone" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app")
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 1, 23, 30))
    user.project_views.create!(repo_name: "me/app", viewed_at: Time.utc(2026, 10, 10, 8), ip_hash: "a")
    user.subscriptions.create!(email: "fan@example.com", github_repo: repo, confirmed_at: Time.utc(2026, 10, 5, 8))

    expect(first_day([ "page", "me/app" ])).to eq(Date.new(2026, 10, 2))
    expect(first_day([ "me/app" ])).to eq(Date.new(2026, 10, 5))
    expect(first_day([ "me/other" ])).to be_nil
  end

  it "counts a click on an entry's link for its project, or the builder's page with none" do
    untagged = create(:entry, user: user, entry_type: "milestone", source: "manual", url: "https://a.example")
    EntryClick.create!(user: user, entry: untagged, clicked_at: Time.utc(2026, 9, 1, 8))

    expect(first_day([ "page" ])).to eq(Date.new(2026, 9, 1))
    expect(first_day([ "me/app" ])).to be_nil
  end

  it "counts a visit to a project's website from its day" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app")
    repo.site_visit_days.create!(day: Date.new(2026, 9, 20), visits: 1, visitors: 1)
    user.project_views.create!(repo_name: "me/app", viewed_at: Time.utc(2026, 10, 10, 8), ip_hash: "a")

    expect(first_day([ "me/app" ])).to eq(Date.new(2026, 9, 20))
    expect(first_day([ "page" ])).to be_nil
  end

  it "refuses without a builder" do
    expect(described_class.new(pages: [ "page" ]).call).to be(false)
  end
end
