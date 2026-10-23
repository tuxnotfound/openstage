require "rails_helper"

RSpec.describe Progress::SummarizeService do
  let(:user) { create(:user) }
  let(:zone) { ActiveSupport::TimeZone["UTC"] }
  let(:projects) { Progress::Projects.new(user.entries.publicly_visible.without_tooling_noise).all }

  before { travel_to Time.utc(2026, 10, 15, 12) }

  def commit(repo, at, title: "Work")
    create(:entry, user: user, repo_name: repo, title: title, occurred_at: at)
  end

  it "gives each project GitHub's words, its weekly commits and its last commit" do
    create(:github_repo, user: user, full_name: "me/app", description: "A tool.")
    create(:github_repo, user: user, full_name: "me/secret", private_repo: true, description: "")
    commit("me/app", 1.day.ago)
    commit("me/app", 8.days.ago)
    commit("me/app", 2.years.ago)
    commit("me/secret", 3.days.ago)
    commit("me/gone", 4.days.ago)
    commit("me/app", 1.hour.ago, title: "Merge pull request #1 from me/branch")

    cards = described_class.new(user: user, projects: projects, zone: zone).tap(&:call!).cards

    app, secret, gone = cards.index_by(&:name).values_at("app", "secret", "gone")
    expect(cards.map(&:name)).to eq(%w[app gone secret])
    expect([ app.name, app.description, app.private_repo, app.commits ]).to eq([ "app", "A tool.", false, 2 ])
    expect(app.weeks.size).to eq(52)
    expect(app.weeks.last(2)).to eq([ 1, 1 ])
    expect(app.last_commit).to eq(Date.new(2026, 10, 14))
    expect([ secret.description, secret.private_repo ]).to eq([ nil, true ])
    expect(gone.private_repo).to be_nil
  end

  it "refuses without a builder or a zone" do
    expect(described_class.new(projects: [], zone: zone).call).to be(false)
    expect(described_class.new(user: user, projects: []).call).to be(false)
  end
end
