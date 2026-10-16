require "rails_helper"
require "support/github_app"

RSpec.describe GithubCommits::FetchStatsService do
  let(:user) { create(:user, github_username: "tux", github_access_token: "gho_user") }
  let(:json) { { "Content-Type" => "application/json" } }

  before { create(:github_repo, user: user, full_name: "tux/app") }

  def commit(sha, repo: "tux/app", at: 1.day.ago, **attrs)
    create(:entry, user: user, source: "github", entry_type: "shipped", external_id: sha, repo_name: repo, occurred_at: at, **attrs)
  end

  def stub_commit(sha, files, status: 200)
    stub_request(:get, "https://api.github.com/repos/tux/app/commits/#{sha}").to_return(status: status, headers: json, body: { files: files }.to_json)
  end

  def fetch
    described_class.new(user: user, tokens: GithubExtras::Tokens.new(user)).tap(&:call!)
  end

  it "records each commit's lines and languages, leaving out files tools write" do
    entry = commit("abc")
    stub_commit("abc", [ { filename: "app/models/user.rb", additions: 30, deletions: 5 },
                         { filename: "app/views/home/index.html.erb", additions: 10, deletions: 0 },
                         { filename: "Gemfile", additions: 1, deletions: 0 },
                         { filename: "config/routes.yml", additions: 2, deletions: 2 },
                         { filename: "Gemfile.lock", additions: 400, deletions: 380 },
                         { filename: "node_modules/x/index.js", additions: 900, deletions: 0 } ])

    expect(fetch.fetched).to eq(1)
    expect(entry.reload).to have_attributes(additions: 43, deletions: 7, files_changed: 4,
                                            languages: { "Ruby" => 36, "ERB" => 10 })
    expect(entry.stats_fetched_at).to be_present
  end

  it "asks only once per commit, and never for old, hidden or excluded repos' commits" do
    commit("done", stats_fetched_at: 1.hour.ago)
    commit("old", at: 9.weeks.ago)
    commit("hidden", hidden: true)
    commit("excluded", repo: "tux/other")
    create(:github_repo, user: user, full_name: "tux/other", included: false)

    expect(fetch.fetched).to eq(0)
  end

  it "marks a commit GitHub no longer has as measured, with nothing to count" do
    entry = commit("gone")
    stub_commit("gone", [], status: 404)

    fetch
    expect(entry.reload).to have_attributes(additions: nil, stats_fetched_at: be_present)
  end

  it "stops when GitHub runs out of calls, leaving the rest for the next sync" do
    first = commit("one", at: 1.hour.ago)
    second = commit("two", at: 2.hours.ago)
    stub_commit("one", [], status: 403)
    stub_commit("two", [ { filename: "a.rb", additions: 1, deletions: 0 } ])

    expect(fetch.fetched).to eq(0)
    expect(first.reload.stats_fetched_at).to be_nil
    expect(second.reload.stats_fetched_at).to be_nil
  end

  context "with a private repo picked in the GitHub App" do
    include_context "with the GitHub App configured"

    it "reads it with the installation token" do
      user.update!(github_installation_id: 42)
      create(:github_repo, user: user, full_name: "tux/secret", private_repo: true)
      commit("s1", repo: "tux/secret")
      allow(GithubAppGateway).to receive(:installation_token).with(42).and_return("ghs_install")
      stub = stub_request(:get, "https://api.github.com/repos/tux/secret/commits/s1")
             .with(headers: { "Authorization" => "Bearer ghs_install" }).to_return(status: 200, headers: json, body: { files: [] }.to_json)

      fetch
      expect(stub).to have_been_requested
    end
  end
end
