require "rails_helper"

RSpec.describe Analytics::GatherPagesService do
  let(:user) { create(:user, rolled_up_to: Time.utc(2026, 10, 24)) }
  let(:row) { Struct.new(:key, :name) }
  let(:pages) { [ row.new("page", "Your stage"), row.new("me/app", "app") ] }

  before { travel_to Time.utc(2026, 10, 24, 12) }

  def gather(first: Date.new(2026, 10, 1), last: Date.new(2026, 10, 24), on: pages)
    described_class.new(user: user, pages: on, split: Analytics::Split.new(user, first: first, last: last)).tap(&:call!)
  end

  # A closed day's totals, and a view, a click and a badge view from today.
  before do
    user.page_counts.create!(page: "page", kind: "source", day: Date.new(2026, 10, 20), value: "(direct)", count: 2)
    user.page_counts.create!(page: "me/app", kind: "country", day: Date.new(2026, 10, 20), value: "PT", count: 3)
    user.page_counts.create!(page: "me/app", kind: "button", day: Date.new(2026, 10, 20), value: "github", count: 4)
    user.page_counts.create!(page: "page", kind: "badge", day: Date.new(2026, 10, 20), value: "github.com", count: 5)
    user.page_counts.create!(page: "page", kind: "badge", day: Date.new(2026, 10, 20), value: "(direct)", count: 1)
    create(:profile_view, user: user, viewed_at: Time.utc(2026, 10, 24, 8), referrer: nil, country: "PT")
    user.project_clicks.create!(repo_name: "me/app", kind: "github", clicked_at: Time.utc(2026, 10, 24, 8))
    user.badge_impressions.create!(kind: "badge", viewed_at: Time.utc(2026, 10, 24, 8), referrer: "example.com")
  end

  it "adds what came today to the closed days' totals" do
    lists = gather

    expect(lists.sources).to eq(Analytics::Ranked.new(rows: [ [ "Direct", 3 ] ], other: 0))
    expect(lists.countries).to eq(Analytics::Ranked.new(rows: [ [ "PT", 4 ] ], other: 0))
    expect(lists.links.rows.map { |link| [ link.title, link.count ] }).to eq([ [ "View on GitHub", 5 ] ])
    expect(lists.badges).to eq([ [ "badge", 7, 2 ], [ "embed", 0, 0 ] ])
  end

  it "reads only the days asked for, and only the pages in view" do
    expect(gather(first: Date.new(2026, 10, 21), last: Date.new(2026, 10, 23)).sources).to eq(Analytics::Ranked.new(rows: [], other: 0))
    expect(gather(on: [ pages.first ]).countries.rows).to eq([ [ "PT", 1 ] ])
  end

  it "lists eight links followed, the busiest first, and what it leaves out" do
    10.times { |i| create(:entry, user: user, repo_name: "me/app", title: "Post #{i}").then { |entry| user.entry_click_days.create!(entry: entry, day: Date.new(2026, 10, 20), clicks: 20 - i) } }

    links = gather.links
    expect(links.rows.map { |link| [ link.title, link.count ] }).to eq((0..7).map { |i| [ "Post #{i}", 20 - i ] })
    expect(links.other).to eq(12 + 11 + 5)
  end

  it "needs a builder and its days" do
    expect(described_class.new(pages: pages).call).to be(false)
  end
end
