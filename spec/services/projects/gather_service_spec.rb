require "rails_helper"

RSpec.describe Projects::GatherService do
  let(:user) { create(:user, pro: true, time_zone: "Europe/Lisbon") }
  let(:repo) { create(:github_repo, user: user, full_name: "me/app", name: "app", homepage: "https://app.example") }

  before { travel_to Time.utc(2026, 10, 26, 12) }

  def gather
    described_class.new(repo: repo).tap(&:call!)
  end

  it "counts the last 30 days' commits and site visits, and the last commit" do
    create(:entry, user: user, repo_name: "me/app", source: "github", entry_type: "shipped", occurred_at: 2.days.ago)
    create(:entry, user: user, repo_name: "me/app", source: "github", entry_type: "shipped", occurred_at: 40.days.ago)
    repo.site_visit_days.create!(day: Date.new(2026, 10, 20), visits: 12, visitors: 5)
    repo.site_visit_days.create!(day: Date.new(2026, 9, 1), visits: 99, visitors: 50)

    overview = gather

    expect([ overview.commits, overview.site_visits, overview.last_commit ]).to eq([ 1, 12, Date.new(2026, 10, 24) ])
  end

  it "says where site visits stand" do
    expect(gather.site_state).to eq(:off)

    repo.update!(site_source: "script")
    expect(gather.site_state).to eq(:counting)

    repo.update!(homepage: nil)
    expect(gather.site_state).to eq(:no_website)
  end

  it "pauses a project on Free while another is the one site it counts" do
    user.update!(pro: false)
    repo.update!(site_source: "script")
    other = create(:github_repo, user: user, site_source: "script")
    other.site_visit_days.create!(day: Date.current, visits: 3, visitors: 1)

    expect([ gather.site_state, gather.free_site ]).to eq([ :paused, other ])
  end

  it "needs a project" do
    expect(described_class.new.call).to be(false)
  end
end
