require "rails_helper"

RSpec.describe GithubPulls::ImportService do
  let(:user) { create(:user, github_username: "tux") }
  let(:json) { { "Content-Type" => "application/json" } }
  let!(:repo) { create(:github_repo, user: user, name: "app", full_name: "tux/app") }

  before do
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: "tux/app", occurred_at: 2.days.ago)
  end

  def pull(id, author: "tux", merged_at: 1.day.ago)
    { id: id, number: id, title: "PR #{id}", merged_at: merged_at&.iso8601, user: { login: author } }
  end

  def pulls_url(full_name = "tux/app")
    "https://api.github.com/repos/#{full_name}/pulls?state=closed&sort=updated&direction=desc&per_page=50"
  end

  def stub_pulls(*pulls, full_name: "tux/app")
    stub_request(:get, pulls_url(full_name)).to_return(status: 200, headers: json, body: pulls.to_json)
  end

  def import
    described_class.new(user: user, tokens: GithubExtras::Tokens.new(user)).tap(&:call!)
  end

  it "keeps the builder's merged pull requests, once" do
    stub_pulls(pull(1), pull(2))

    expect(import.imported).to eq(2)
    expect(import.imported).to eq(0)
    expect(GithubActivity.where(user: user).pluck(:kind, :external_id, :title, :github_repo_id)).to contain_exactly(
      [ "pull_request", 1, "PR 1", repo.id ], [ "pull_request", 2, "PR 2", repo.id ]
    )
  end

  it "leaves out a teammate's pull requests and the ones merged before the window" do
    stub_pulls(pull(1, author: "teammate"), pull(2, merged_at: 9.weeks.ago), pull(3, author: "TUX"))

    expect(import.imported).to eq(1)
    expect(GithubActivity.pluck(:external_id)).to eq([ 3 ])
  end

  it "asks only about included repos with recent commits" do
    quiet = create(:github_repo, user: user, full_name: "tux/quiet")
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: quiet.full_name, occurred_at: 3.months.ago)
    excluded = create(:github_repo, user: user, full_name: "tux/hidden", included: false)
    create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: excluded.full_name, occurred_at: 2.days.ago)
    stub_pulls

    import
    expect(a_request(:get, %r{/repos/tux/(quiet|hidden)/pulls})).not_to have_been_made
  end

  context "with a second active repo" do
    before do
      create(:github_repo, user: user, name: "site", full_name: "tux/site")
      create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: "tux/site", occurred_at: 1.day.ago)
    end

    it "skips a repo the token cannot read and carries on" do
      stub_request(:get, pulls_url).to_return(status: 403, headers: json, body: "{}")
      stub_pulls(pull(1), full_name: "tux/site")

      expect(import.imported).to eq(1)
    end

    it "stops at the rate limit" do
      limited = { status: 403, headers: json.merge("X-RateLimit-Remaining" => "0"), body: "{}" }
      stub_request(:get, pulls_url).to_return(limited)
      stub_request(:get, pulls_url("tux/site")).to_return(limited)

      expect(import.imported).to eq(0)
      expect(a_request(:get, %r{/repos/tux/(app|site)/pulls})).to have_been_made.once
    end
  end
end
