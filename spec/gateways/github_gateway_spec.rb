require "rails_helper"

RSpec.describe GithubGateway do
  let(:json) { { "Content-Type" => "application/json" } }
  let(:api) { "https://api.github.com/repos/me/app" }

  def answer(body)
    { status: 200, headers: json, body: body.to_json }
  end

  describe ".branches" do
    it "returns each branch with the commit it points at, read with the given token" do
      stub_request(:get, "#{api}/branches?per_page=100")
        .with(headers: { "Authorization" => "Bearer tok" })
        .to_return(answer([ { name: "main", commit: { sha: "aaa" } }, { name: "feature/x", commit: { sha: "bbb" } } ]))

      expect(described_class.branches("me/app", token: "tok")).to eq([
        GithubGateway::Branch.new(name: "main", sha: "aaa"),
        GithubGateway::Branch.new(name: "feature/x", sha: "bbb")
      ])
    end

    # A spent rate limit and a repo the token cannot read are both 403s.
    it "raises RateLimited when the rate limit is spent" do
      stub_request(:get, "#{api}/branches?per_page=100")
        .to_return(status: 403, headers: { "x-ratelimit-remaining" => "0" }, body: "")

      expect { described_class.branches("me/app", token: "tok") }.to raise_error(ApplicationGateway::RateLimited)
    end
  end

  describe ".commits_ahead" do
    it "returns the commits the head has that the base lacks" do
      stub_request(:get, "#{api}/compare/main...bbb").to_return(answer(
        commits: [ { sha: "c1", html_url: "https://github.com/me/app/commit/c1", author: { login: "me" },
                     commit: { message: "Add search\n\nDetails", author: { date: "2026-10-12T10:00:00Z", email: "me@example.com" } } } ]
      ))

      commit = described_class.commits_ahead("me/app", base: "main", head: "bbb", token: "tok").sole

      expect(commit).to have_attributes(sha: "c1", message: "Add search\n\nDetails", author_login: "me",
                                        author_email: "me@example.com", html_url: "https://github.com/me/app/commit/c1")
      expect(commit.authored_at).to eq(Time.utc(2026, 10, 12, 10))
    end

    # GitHub leaves author empty when the email is not tied to an account.
    it "copes with a commit GitHub ties to no account" do
      stub_request(:get, "#{api}/compare/main...bbb").to_return(answer(
        commits: [ { sha: "c1", author: nil, commit: { message: "x", author: { date: "2026-10-12T10:00:00Z", email: "a@b.c" } } } ]
      ))

      expect(described_class.commits_ahead("me/app", base: "main", head: "bbb", token: "tok").sole.author_login).to be_nil
    end
  end

  describe ".merged_pull_numbers" do
    it "returns only the merged pull requests a commit belongs to" do
      stub_request(:get, "#{api}/commits/sq1/pulls")
        .to_return(answer([ { number: 12, merged_at: "2026-10-12T10:00:00Z" }, { number: 13, merged_at: nil } ]))

      expect(described_class.merged_pull_numbers("me/app", "sq1", token: "tok")).to eq([ 12 ])
    end
  end

  describe ".pull_commit_shas" do
    it "returns the SHAs of a pull request's commits" do
      stub_request(:get, "#{api}/pulls/12/commits?per_page=100").to_return(answer([ { sha: "c1" }, { sha: "c2" } ]))

      expect(described_class.pull_commit_shas("me/app", 12, token: "tok")).to eq(%w[c1 c2])
    end
  end
end
