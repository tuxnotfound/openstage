require "rails_helper"

RSpec.describe Analytics::ReportService do
  let(:user) { create(:user) }

  before do
    travel_to Time.utc(2026, 10, 24, 12)
    create(:entry, user: user, repo_name: "me/app")
    create(:entry, user: user, repo_name: "me/app")
    create(:entry, user: user, repo_name: "me/lib")
  end

  def report(**options)
    described_class.new(user: user, **options).tap(&:call!)
  end

  it "has the builder's page and each project, in the public page's order and colours" do
    pages = report.pages

    expect(pages.map(&:name)).to eq([ "Your page", "app", "lib" ])
    expect(pages.map(&:rank)).to eq([ nil, 0, 1 ])
  end

  it "totals the pages picked, against the days before, for the number picked" do
    user.project_views.create!(repo_name: "me/app", viewed_at: 2.days.ago, ip_hash: "a")
    user.project_views.create!(repo_name: "me/app", viewed_at: 2.days.ago, ip_hash: "b")
    user.project_views.create!(repo_name: "me/app", viewed_at: 35.days.ago, ip_hash: "c")
    create(:profile_view, user: user, viewed_at: 2.days.ago)

    picked = report(picked: [ "me/app" ], metrics: [ "views" ])

    expect(picked.selected.map(&:name)).to eq([ "app" ])
    expect(picked.total("views")).to eq(2)
    expect(picked.change("views")).to eq(100)
    expect(picked.metrics).to eq([ "views" ])
    expect(picked.series(picked.selected.first, "views").sum).to eq(2)
    expect(picked.series(picked.selected.first, "views").size).to eq(30)
  end

  it "picks every page, and charts commits and site visits, when the params name none it knows" do
    unknown = report(picked: [ "nope" ], metrics: [ "nope" ], range: "nope")

    expect(unknown.selected.size).to eq(3)
    expect(unknown.metrics).to eq(%w[commits site])
    expect(unknown.window.range).to eq("30d")
  end

  it "lists the links visitors followed, busiest first, on the pages picked" do
    entry = create(:entry, user: user, repo_name: "me/lib", entry_type: "milestone", source: "manual", title: "Launched", url: "https://lib.example")
    2.times { EntryClick.create!(user: user, entry: entry, clicked_at: 1.day.ago) }
    user.project_clicks.create!(repo_name: "me/app", kind: "github", clicked_at: 1.day.ago)

    expect(report.links.map { |link| [ link.title, link.page.name, link.count ] }).to eq([ [ "Launched", "lib", 2 ], [ "View on GitHub", "app", 1 ] ])
    expect(report(picked: [ "me/app" ]).links.map(&:title)).to eq([ "View on GitHub" ])
  end

  it "starts its window at the first day the pages picked had anything" do
    user.project_views.create!(repo_name: "me/app", viewed_at: 3.days.ago, ip_hash: "a")

    picked = report(picked: [ "me/app" ], range: "30d")

    expect(picked.window.days.first).to eq(3.days.ago.to_date)
    expect(picked.window.buckets.size).to eq(4)
    expect(report(range: "30d").window.days.first).to eq(3.days.ago.to_date)
  end

  it "refuses without a builder" do
    expect(described_class.new.call).to be(false)
  end
end
