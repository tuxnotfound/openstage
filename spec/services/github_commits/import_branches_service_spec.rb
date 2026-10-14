require "rails_helper"

RSpec.describe GithubCommits::ImportBranchesService do
  let(:user) { create(:user, github_username: "me") }
  let(:repo) { create(:github_repo, user: user, full_name: "me/app", default_branch: "main") }

  def branch(name, sha) = GithubGateway::Branch.new(name: name, sha: sha)

  def commit(sha, login: "me", at: 1.day.ago)
    GithubGateway::Commit.new(sha: sha, message: "Work #{sha}", authored_at: at, html_url: "https://github.com/me/app/commit/#{sha}",
                              author_login: login, author_email: nil)
  end

  def import
    described_class.new(user: user, repo: repo, token: "tok").tap(&:call!)
  end

  before do
    allow(GithubGateway).to receive(:branches).with("me/app", token: "tok").and_return(
      [ branch("main", "m1"), branch("feature", "f1"), branch("dependabot/npm/x", "d1") ]
    )
    allow(GithubGateway).to receive(:commits_ahead).and_return([])
    allow(GithubGateway).to receive(:commits_ahead).with("me/app", base: "main", head: "f1", token: "tok")
                                                   .and_return([ commit("c1"), commit("c2") ])
  end

  it "puts the builder's commits on other branches on the page, tagged with their branch" do
    expect(import.added).to eq(2)

    expect(user.entries.pluck(:external_id, :branch)).to contain_exactly([ "c1", "feature" ], [ "c2", "feature" ])
  end

  it "reads neither the default branch nor a bot's branch" do
    import

    expect(GithubGateway).to have_received(:commits_ahead).once
  end

  it "remembers each branch's head, and reads a branch again only once it moves" do
    import
    expect(repo.reload.branch_heads).to eq("feature" => "f1")

    import
    expect(GithubGateway).to have_received(:commits_ahead).once

    allow(GithubGateway).to receive(:branches).and_return([ branch("feature", "f2") ])
    import
    expect(GithubGateway).to have_received(:commits_ahead).with("me/app", base: "main", head: "f2", token: "tok")
  end

  it "forgets a deleted branch" do
    import
    allow(GithubGateway).to receive(:branches).and_return([ branch("main", "m1") ])

    import

    expect(repo.reload.branch_heads).to eq({})
  end

  it "leaves out other people's commits and work older than a first sync reads" do
    allow(GithubGateway).to receive(:commits_ahead).and_return([ commit("theirs", login: "teammate"), commit("old", at: 2.years.ago) ])

    expect(import.added).to eq(0)
  end

  # Unread branches keep their old heads, so the next sync reads them again.
  it "keeps the old heads when GitHub fails mid-read" do
    repo.update!(branch_heads: { "feature" => "f0" })
    allow(GithubGateway).to receive(:commits_ahead).and_raise(ApplicationGateway::ServerError.new(status: 502))

    expect { import }.to raise_error(ApplicationGateway::ServerError)
    expect(repo.reload.branch_heads).to eq("feature" => "f0")
  end
end
