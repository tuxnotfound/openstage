require "rails_helper"

RSpec.describe Analytics::FindStartService do
  let(:user) { create(:user, time_zone: "Europe/Lisbon") }

  before { travel_to Time.utc(2026, 10, 24, 12) }

  def firsts
    described_class.new(user: user).tap(&:call!).firsts
  end

  it "finds the first day each page counted each number, in the builder's zone" do
    repo = create(:github_repo, user: user, full_name: "me/app", name: "app")
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 1, 23, 30))
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 9, 8))
    user.project_views.create!(repo_name: "me/app", viewed_at: Time.utc(2026, 10, 10, 8), ip_hash: "a")
    user.subscriptions.create!(email: "fan@example.com", github_repo: repo, confirmed_at: Time.utc(2026, 10, 5, 8))
    create(:entry, user: user, repo_name: "me/app", occurred_at: Time.utc(2026, 9, 3, 8))
    repo.site_visit_days.create!(day: Date.new(2026, 9, 20), visits: 1, visitors: 1)

    expect(firsts).to include("visitors" => { "page" => Date.new(2026, 10, 2), "me/app" => Date.new(2026, 10, 10) },
                              "views" => { "page" => Date.new(2026, 10, 2), "me/app" => Date.new(2026, 10, 10) },
                              "follows" => { "me/app" => Date.new(2026, 10, 5) }, "commits" => { "me/app" => Date.new(2026, 9, 3) },
                              "visits" => { "me/app" => Date.new(2026, 9, 20) }, "clicks" => {})
  end

  it "counts a click on an entry's link for its project, or the builder's page with none, the earlier of a project's two" do
    untagged = create(:entry, user: user, entry_type: "milestone", source: "manual", url: "https://a.example")
    tagged = create(:entry, user: user, repo_name: "me/app", entry_type: "milestone", source: "manual", url: "https://b.example")
    EntryClick.create!(user: user, entry: untagged, clicked_at: Time.utc(2026, 9, 1, 8))
    EntryClick.create!(user: user, entry: tagged, clicked_at: Time.utc(2026, 9, 12, 8))
    user.project_clicks.create!(repo_name: "me/app", kind: "visit", clicked_at: Time.utc(2026, 9, 10, 8))

    expect(firsts["clicks"]).to eq("page" => Date.new(2026, 9, 1), "me/app" => Date.new(2026, 9, 10))
  end

  it "leaves out the commits the public page leaves out" do
    create(:entry, user: user, repo_name: "me/app", occurred_at: Time.utc(2026, 9, 3, 8), visibility: :private_entry)
    create(:entry, user: user, repo_name: "me/app", occurred_at: Time.utc(2026, 9, 8, 8))

    expect(firsts["commits"]).to eq("me/app" => Date.new(2026, 9, 8))
  end

  it "refuses without a builder" do
    expect(described_class.new.call).to be(false)
  end
end
