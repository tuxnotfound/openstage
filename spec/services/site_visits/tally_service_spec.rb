require "rails_helper"

RSpec.describe SiteVisits::TallyService do
  let(:user) { create(:user, pro: true, time_zone: "Europe/Lisbon") }
  let(:repo) do
    create(:github_repo, user: user, homepage: "https://app.example", site_source: "script", site_first_visit_at: 10.days.ago)
  end

  before { travel_to Time.utc(2026, 10, 26, 12) }

  it "adds up the window's visits per point, from the first day counted" do
    repo.site_visit_days.create!(day: Date.new(2026, 10, 20), visits: 7, visitors: 3)
    repo.site_visit_days.create!(day: Date.new(2026, 10, 26), visits: 5, visitors: 2)

    tally = described_class.new(repo: repo, range: "30d").tap(&:call!)

    expect(tally.window.first).to eq(Date.new(2026, 10, 20))
    expect(tally.values).to eq([ 7, 0, 0, 0, 0, 0, 5 ])
    expect([ tally.visits, tally.visitors ]).to eq([ 12, 5 ])
  end

  it "draws the project's line in its colour, by week once the history is short" do
    repo.site_visit_days.create!(day: Date.new(2026, 10, 20), visits: 7, visitors: 3)
    tally = described_class.new(repo: repo, range: "12m").tap(&:call!)

    chart = ProgressChart::SiteVisits.new(tally, name: "app", rank: 2)

    expect(chart.paths.sole.last).to eq(2)
    expect(chart.aria_label).to eq("Site visits per week, last 12 months")
  end

  it "refuses a project whose page does not show them" do
    repo.update!(site_visits_shown: false)

    expect(described_class.new(repo: repo).call).to be(false)
  end
end
