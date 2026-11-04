require "rails_helper"

# What analytics shows must not change when the rollup takes a day from the
# raw rows, or when the hashes go.
RSpec.describe "Analytics after the rollup" do
  let(:user) { create(:user, pro: true, time_zone: "America/Los_Angeles") }
  let!(:app) { create(:github_repo, user: user, full_name: "me/app", name: "app") }
  let!(:tagged) { create(:entry, user: user, repo_name: "me/app", occurred_at: 3.days.ago, entry_type: "milestone", source: "manual", url: "https://a.example", title: "Tagged") }
  let!(:untagged) { create(:entry, user: user, occurred_at: 3.days.ago, entry_type: "milestone", source: "manual", url: "https://b.example", title: "Untagged") }

  let(:views) { [ [ nil ], [ "30d" ], [ "90d" ], [ "12m" ], [ "all" ], [ "2026-10-01..2026-10-20" ], [ "30d", [ "me/app" ] ], [ "all", [ "page" ] ] ] }
  let(:numbers) { %w[commits views visitors clicks follows] }

  before do
    travel_to Time.utc(2026, 10, 25, 12)
    srand(7)
    [ 0, 1, 2, 5, 11, 40, 120, 300 ].each { |back| visit(back.days.ago) }
    user.subscriptions.create!(email: "fan@example.com", github_repo: app, confirmed_at: 2.days.ago)
  end

  def visit(at)
    [ at.change(hour: 3), at.change(hour: 7, min: 30), at.change(hour: 20) ].each_with_index do |time, i|
      next if time > Time.current

      create(:profile_view, user: user, viewed_at: time, ip_hash: "h#{i % 2}#{time.to_date}", referrer: [ "x.com", nil, "news.ycombinator.com" ][i], country: [ "PT", nil, "T1" ][i])
      user.project_views.create!(repo_name: "me/app", viewed_at: time, ip_hash: "p#{time.to_date}", referrer: [ nil, "github.com", "x.com" ][i], country: "US")
      user.project_clicks.create!(repo_name: "me/app", kind: %w[visit github][i % 2], clicked_at: time)
      EntryClick.create!(user: user, entry: [ tagged, untagged ][i % 2], clicked_at: time)
      user.badge_impressions.create!(kind: %w[badge embed][i % 2], viewed_at: time, referrer: [ "github.com", nil, "site.example" ][i])
    end
  end

  def report(range, pages = nil)
    service = Analytics::ReportService.new(user: User.find(user.id), range: range, show: numbers, pages: pages).tap(&:call!)
    JSON.parse(AnalyticsViewSerializer.new(service).to_json)
  end

  def shown
    views.to_h { |range, pages| [ [ range, pages ], report(range, pages) ] }
  end

  it "shows the same before the rollup, after it, and with the hashes gone" do
    before_rollup = shown
    expect(before_rollup.values.first.to_s).to include("Hacker News")

    Analytics::RollUpService.new(user: user).call!
    expect(PageDay.where(user: user)).to be_present
    expect(shown).to eq(before_rollup)

    Analytics::ForgetVisitorsService.new.call!
    expect(user.profile_views.where(ip_hash: nil)).to be_present
    expect(shown).to eq(before_rollup)
  end

  it "shows the same the next night, the day before read from raw rows until then" do
    Analytics::RollUpService.new(user: user).call!
    visit(Time.current)
    travel 1.day
    raw = shown

    Analytics::RollUpService.new(user: user).call!
    Analytics::ForgetVisitorsService.new.call!

    expect(shown).to eq(raw)
  end

  it "counts a click for the project its entry moved to, and drops it with the entry" do
    Analytics::RollUpService.new(user: user).call!
    clicks_on = ->(page) { Analytics::CountService.new(user: User.find(user.id), from: nil).tap(&:call!).counts["clicks"].fetch(page, {}).values.sum }
    on_app = clicks_on.call("me/app")
    on_page = clicks_on.call("page")

    untagged.update!(repo_name: "me/app")
    expect([ clicks_on.call("me/app"), clicks_on.call("page") ]).to eq([ on_app + on_page, 0 ])

    expect { untagged.destroy! }.to change(EntryClickDay, :count).by(-EntryClickDay.where(entry: untagged).count)
    expect(clicks_on.call("me/app")).to be < on_app + on_page
  end
end
