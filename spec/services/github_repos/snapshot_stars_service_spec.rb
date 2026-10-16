require "rails_helper"

RSpec.describe GithubRepos::SnapshotStarsService do
  let(:user) { create(:user) }

  it "writes down today's stars for each included repo, once a day" do
    repo = create(:github_repo, user: user, stars_count: 12)
    create(:github_repo, user: user, stars_count: 5, included: false)
    create(:github_repo, user: user, stars_count: nil)

    described_class.new(user: user).call!
    repo.update!(stars_count: 14)
    described_class.new(user: user).call!

    expect(GithubRepoStarCount.pluck(:github_repo_id, :recorded_on, :stars)).to eq([ [ repo.id, Date.current, 14 ] ])
  end

  it "goes with the repo" do
    repo = create(:github_repo, user: user, stars_count: 3)
    described_class.new(user: user).call!

    repo.destroy!
    expect(GithubRepoStarCount.count).to eq(0)
  end
end
