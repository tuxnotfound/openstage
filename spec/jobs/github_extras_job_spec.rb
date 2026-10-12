require "rails_helper"

RSpec.describe GithubExtrasJob do
  let(:user) { create(:user, github_username: "tux") }

  it "refreshes stars, releases and commit stats for the builder" do
    repo = create(:github_repo, user: user, full_name: "tux/app", stars_count: 4)
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: repo.full_name, external_id: "abc", occurred_at: 1.day.ago)
    stub_request(:get, "https://api.github.com/repos/tux/app/releases?per_page=30")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: "[]")
    stub_request(:get, "https://api.github.com/repos/tux/app/commits/abc")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { files: [ { filename: "a.rb", additions: 2, deletions: 1 } ] }.to_json)

    described_class.perform_now(user.id)

    expect(GithubRepoStarCount.pluck(:stars)).to eq([ 4 ])
    expect(user.entries.first.additions).to eq(2)
  end

  it "does nothing for a builder without a GitHub token, or gone" do
    user.update!(github_access_token: nil)
    expect { described_class.perform_now(user.id) }.not_to raise_error
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
