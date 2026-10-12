require "rails_helper"

RSpec.describe GithubExtrasJob do
  let(:user) { create(:user, github_username: "tux") }

  it "refreshes stars, releases, pull requests, deploys and commit stats for the builder" do
    json = { "Content-Type" => "application/json" }
    repo = create(:github_repo, user: user, full_name: "tux/app", stars_count: 4)
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: repo.full_name, external_id: "abc", occurred_at: 1.day.ago)
    stub_request(:get, "https://api.github.com/repos/tux/app/releases?per_page=30").to_return(status: 200, headers: json, body: "[]")
    stub_request(:get, "https://api.github.com/repos/tux/app/pulls?state=closed&sort=updated&direction=desc&per_page=50")
      .to_return(status: 200, headers: json, body: [ { id: 1, number: 1, title: "Ship", merged_at: 1.day.ago.iso8601, user: { login: "tux" } } ].to_json)
    stub_request(:get, "https://api.github.com/repos/tux/app/deployments?per_page=50")
      .to_return(status: 200, headers: json, body: [ { id: 2, environment: "production", created_at: 1.day.ago.iso8601 } ].to_json)
    stub_request(:get, "https://api.github.com/repos/tux/app/commits/abc")
      .to_return(status: 200, headers: json, body: { files: [ { filename: "a.rb", additions: 2, deletions: 1 } ] }.to_json)

    described_class.perform_now(user.id)

    expect(GithubRepoStarCount.pluck(:stars)).to eq([ 4 ])
    expect(GithubActivity.pluck(:kind)).to contain_exactly("pull_request", "deployment")
    expect(user.entries.first.additions).to eq(2)
  end

  it "does nothing for a builder without a GitHub token, or gone" do
    user.update!(github_access_token: nil)
    expect { described_class.perform_now(user.id) }.not_to raise_error
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
