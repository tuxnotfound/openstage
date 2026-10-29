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
    expect([ gather.site_state, gather.slot_project ]).to eq([ :off, nil ])

    repo.update!(site_source: "script", site_set_up_at: 1.day.ago)
    expect(gather.site_state).to eq(:counting)

    repo.update!(homepage: nil)
    expect(gather.site_state).to eq(:no_website)
  end

  it "pauses a project with its script on while Free counts the one set up first, and names that one" do
    user.update!(pro: false)
    first = create(:github_repo, user: user, name: "lunchbox", homepage: "https://lunchbox.example", site_set_up_at: 10.days.ago)
    repo.update!(site_source: "script", site_set_up_at: 3.days.ago)
    expect([ gather.site_state, gather.slot_project ]).to eq([ :paused, first ])

    repo.update!(site_source: nil, homepage: nil)
    expect([ gather.site_state, gather.slot_project ]).to eq([ :no_website, first ])

    first.destroy!
    expect([ gather.site_state, gather.slot_project ]).to eq([ :no_website, nil ])
  end

  it "needs a project" do
    expect(described_class.new.call).to be(false)
  end
end
