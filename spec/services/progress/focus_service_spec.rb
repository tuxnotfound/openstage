require "rails_helper"
require "support/progress_data"

RSpec.describe Progress::FocusService do
  include ProgressData

  let(:user) { create(:user) }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  it "gathers one project's page, its card, the others and its latest highlight" do
    service = described_class.new(user: user, slug: "Trained-On", range: "90d")

    expect(service.call).to be(true)
    expect(service.project.repo).to eq(progress_repo(4))
    expect(service.page.section.selected.map(&:name)).to eq([ "trained-on" ])
    expect(service.card.repo).to eq(progress_repo(4))
    expect(service.others.map(&:repo)).not_to include(progress_repo(4))
    expect(service.news.repo_name).to eq(progress_repo(4))
    expect(service.highlights).to eq(user.entries.highlights.where(repo_name: progress_repo(4)).count)
    expect(service.first_commit).to eq(user.entries.commits.where(repo_name: progress_repo(4)).minimum(:occurred_at))
  end

  it "says whether visitors see its commits, as its builder picks" do
    repo = create(:github_repo, user: user, full_name: progress_repo(4), name: "trained-on")
    service = described_class.new(user: user, slug: "trained-on").tap(&:call!)
    expect(service.commits_shown?).to be(true)

    repo.update!(hidden_numbers: [ "commits" ])
    service = described_class.new(user: user, slug: "trained-on").tap(&:call!)
    expect(service.commits_shown?).to be(false)
    expect(service.first_commit).to be_present
  end

  it "counts the commits of each other builder on the repo who shows them, the ones who hide them last" do
    ada = create(:user, username: "ada")
    create(:github_repo, user: ada, full_name: progress_repo(4), name: "trained-on", hidden_numbers: [ "commits" ])
    3.times { create(:entry, user: ada, repo_name: progress_repo(4)) }
    zed = create(:user, username: "zed")
    create(:entry, user: zed, repo_name: progress_repo(4))

    co_builders = described_class.new(user: user, slug: "trained-on").tap(&:call!).co_builders

    expect(co_builders.map { |co| [ co.user.username, co.commits ] }).to eq([ [ "zed", 1 ], [ "ada", nil ] ])
  end

  it "refuses a name that is no project on the page" do
    service = described_class.new(user: user, slug: "nope")

    expect(service.call).to be(false)
    expect(service.errors[:slug]).to be_present
  end

  it "refuses without a builder or a name" do
    expect(described_class.new(slug: "openstage").call).to be(false)
    expect(described_class.new(user: user).call).to be(false)
  end
end
