require "rails_helper"

RSpec.describe Analytics::CountService do
  let(:user) { create(:user, time_zone: "Europe/Lisbon") }
  let(:window) { Analytics::Window.new(range: "7d", today: Date.new(2026, 10, 24)) }

  before { travel_to Time.utc(2026, 10, 24, 12) }

  def counts
    described_class.new(user: user, window: window).tap(&:call!).counts
  end

  it "counts each day in the builder's zone, a visitor once a day" do
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 21, 23, 30), ip_hash: "a")
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 22, 8), ip_hash: "a")

    expect(counts["views"]["page"]).to eq(Date.new(2026, 10, 22) => 2)
    expect(counts["visitors"]["page"]).to eq(Date.new(2026, 10, 22) => 1)
  end

  it "counts a project's page, its followers and its clicks under its repo" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app")
    user.project_views.create!(repo_name: "me/app", viewed_at: 1.day.ago, ip_hash: "b")
    user.subscriptions.create!(email: "fan@example.com", github_repo: repo, confirmed_at: 2.days.ago)
    user.subscriptions.create!(email: "all@example.com", confirmed_at: 2.days.ago)
    user.project_clicks.create!(repo_name: "me/app", kind: "github", clicked_at: 1.day.ago)

    expect(counts["views"]["me/app"].values.sum).to eq(1)
    expect(counts["follows"]["me/app"].values.sum).to eq(1)
    expect(counts["follows"]["page"].values.sum).to eq(1)
    expect(counts["clicks"]["me/app"].values.sum).to eq(1)
  end

  it "counts a click on an entry's link for the entry's project, or the builder's page" do
    tagged = create(:entry, user: user, repo_name: "me/app", entry_type: "milestone", source: "manual", url: "https://a.example")
    untagged = create(:entry, user: user, entry_type: "milestone", source: "manual", url: "https://b.example")
    EntryClick.create!(user: user, entry: tagged, clicked_at: 1.day.ago)
    EntryClick.create!(user: user, entry: untagged, clicked_at: 1.day.ago)

    expect(counts["clicks"]["me/app"].values.sum).to eq(1)
    expect(counts["clicks"]["page"].values.sum).to eq(1)
  end

  it "covers the days before the window too, and nothing older" do
    create(:profile_view, user: user, viewed_at: 10.days.ago)
    create(:profile_view, user: user, viewed_at: 20.days.ago)

    expect(counts["views"]["page"].values.sum).to eq(1)
  end

  it "refuses without a builder or a window" do
    expect(described_class.new(window: window).call).to be(false)
    expect(described_class.new(user: user).call).to be(false)
  end
end
