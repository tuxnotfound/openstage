require "rails_helper"

RSpec.describe SiteVisits::TallyService do
  let(:user) { create(:user, pro: true, time_zone: "Europe/Lisbon") }
  let(:app) { create(:github_repo, user: user, full_name: "me/app", homepage: "https://app.example", site_source: "script") }
  let(:lib) { create(:github_repo, user: user, full_name: "me/lib", homepage: "https://lib.example", site_source: "script") }

  before { travel_to Time.utc(2026, 10, 26, 12) }

  it "adds up each project's visits per point, from the first day any counted, and the window's totals" do
    app.site_visit_days.create!(day: Date.new(2026, 10, 20), visits: 7, visitors: 3)
    lib.site_visit_days.create!(day: Date.new(2026, 10, 26), visits: 5, visitors: 2)

    tally = described_class.new(repos: [ app, lib ], range: "30d").tap(&:call!)

    expect(tally.window.first).to eq(Date.new(2026, 10, 20))
    expect(tally.lines).to eq("me/app" => [ 7, 0, 0, 0, 0, 0, 0 ], "me/lib" => [ 0, 0, 0, 0, 0, 0, 5 ])
    expect([ tally.visits, tally.visitors ]).to eq([ 12, 5 ])
  end

  it "draws a dotted line per project in its colour, by week once the history is short" do
    app.site_visit_days.create!(day: Date.new(2026, 10, 20), visits: 7, visitors: 3)
    tally = described_class.new(repos: [ app ], range: "12m").tap(&:call!)
    projects = Progress::Projects.new(Entry.none)

    chart = ProgressChart::SiteVisits.new(tally, projects: projects)

    expect(chart.paths.sole.last).to be(true)
    expect(chart.aria_label).to eq("Site visits per week by project, last 12 months")
    expect(chart.note).to start_with("Visits to app.example per week")
  end

  it "needs projects" do
    expect(described_class.new(repos: []).call).to be(false)
  end
end
