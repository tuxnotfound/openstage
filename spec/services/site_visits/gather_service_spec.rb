require "rails_helper"

RSpec.describe SiteVisits::GatherService do
  let(:user) { create(:user, pro: true, username: "builder") }
  let!(:app) do
    create(:github_repo, user: user, full_name: "builder/app", name: "app", homepage: "https://app.example",
                         site_source: "script", site_first_visit_at: 3.days.ago)
  end
  let!(:lib) do
    create(:github_repo, user: user, full_name: "builder/lib", name: "lib", homepage: "https://lib.example",
                         site_source: "script", site_first_visit_at: 3.days.ago, site_visits_shown: false)
  end

  before do
    travel_to Time.utc(2026, 10, 26, 12)
    [ app, lib ].each do |repo|
      create(:entry, user: user, repo_name: repo.full_name, occurred_at: 2.days.ago)
      repo.site_visit_days.create!(day: Date.new(2026, 10, 24), visits: 14, visitors: 5)
    end
  end

  def gather(range: "30d", dashboard: false, repos: [])
    compose = Progress::ComposeService.new(user: user, range: range, repos: repos, rolling: true).tap(&:call!)
    described_class.new(user: user, section: compose.section, dashboard: dashboard).tap(&:call!)
  end

  it "draws on a public page the projects in view whose builder shows their visits" do
    expect(gather.repos).to eq([ app ])
    expect(gather(repos: [ "builder/lib" ]).any?).to be(false)
  end

  it "gathers on the dashboard every project counted, shown on its page or not" do
    expect(gather(dashboard: true).repos).to contain_exactly(app, lib)
  end

  it "puts the visits on the section's points, as 7-day averages over 30 days and sums by week over 90" do
    expect(gather.series["builder/app"].last(3)).to eq([ 2.0, 2.0, 2.0 ])
    expect(gather(range: "90d").series["builder/app"].sum).to eq(14)
  end

  it "needs a builder and a section" do
    expect(described_class.new.call).to be(false)
  end
end
