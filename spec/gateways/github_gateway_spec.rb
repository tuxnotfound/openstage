require "rails_helper"

RSpec.describe GithubGateway do
  let(:json) { { "Content-Type" => "application/json" } }
  let(:api) { "https://api.github.com/repos/me/app" }

  def answer(body)
    { status: 200, headers: json, body: body.to_json }
  end

  describe ".commit_files" do
    it "reads each changed file's lines with the given token" do
      stub_request(:get, "https://api.github.com/repos/tux/app/commits/abc123")
        .with(headers: { "Authorization" => "Bearer gho_x", "X-GitHub-Api-Version" => "2022-11-28" })
        .to_return(status: 200, headers: json, body: { stats: { additions: 12, deletions: 3 },
                                                       files: [ { filename: "app/a.rb", additions: 10, deletions: 3, changes: 13 },
                                                                { filename: "README.md", additions: 2, deletions: 0, changes: 2 } ] }.to_json)

      files = described_class.commit_files("tux/app", "abc123", token: "gho_x")
      expect(files).to eq([ GithubGateway::CommitFile.new(filename: "app/a.rb", additions: 10, deletions: 3),
                            GithubGateway::CommitFile.new(filename: "README.md", additions: 2, deletions: 0) ])
    end

    it "escapes the owner and repo but keeps the slash between them" do
      stub = stub_request(:get, "https://api.github.com/repos/tux/a%20b/commits/abc").to_return(status: 200, headers: json, body: "{}")

      expect(described_class.commit_files("tux/a b", "abc", token: "t")).to eq([])
      expect(stub).to have_been_requested
    end

    it "raises for a commit GitHub cannot show" do
      stub_request(:get, "https://api.github.com/repos/tux/app/commits/gone").to_return(status: 422, headers: json, body: "{}")
      stub_request(:get, "https://api.github.com/repos/tux/app/commits/missing").to_return(status: 404, headers: json, body: "{}")

      expect { described_class.commit_files("tux/app", "gone", token: "t") }.to raise_error(ApplicationGateway::ClientError)
      expect { described_class.commit_files("tux/app", "missing", token: "t") }.to raise_error(ApplicationGateway::NotFound)
    end
  end

  describe ".releases" do
    it "lists a repo's releases, newest first" do
      stub_request(:get, "https://api.github.com/repos/tux/app/releases?per_page=30")
        .to_return(status: 200, headers: json, body: [ { id: 7, name: "", tag_name: "v1.0", html_url: "https://github.com/tux/app/releases/v1.0",
                                                         published_at: "2026-10-08T18:00:00Z", author: { login: "tux" }, draft: false } ].to_json)

      expect(described_class.releases("tux/app", token: "t").first)
        .to have_attributes(id: 7, tag_name: "v1.0", author_login: "tux", published_at: "2026-10-08T18:00:00Z", draft: false)
    end
  end

  describe ".merged_pulls" do
    it "lists recently closed pull requests that were merged, leaving out the ones closed without a merge" do
      stub_request(:get, "https://api.github.com/repos/tux/app/pulls?state=closed&sort=updated&direction=desc&per_page=50")
        .with(headers: { "Authorization" => "Bearer t" })
        .to_return(status: 200, headers: json, body: [ { id: 11, number: 4, title: "Arcade mode", merged_at: "2026-10-08T18:00:00Z", user: { login: "tux" } },
                                                       { id: 12, number: 5, title: "Abandoned", merged_at: nil, user: { login: "tux" } } ].to_json)

      expect(described_class.merged_pulls("tux/app", token: "t")).to eq([
        GithubGateway::PullRequest.new(id: 11, number: 4, title: "Arcade mode", merged_at: "2026-10-08T18:00:00Z", author_login: "tux")
      ])
    end
  end

  describe ".deployments" do
    it "lists a repo's latest deployments" do
      stub_request(:get, "https://api.github.com/repos/tux/app/deployments?per_page=50")
        .to_return(status: 200, headers: json, body: [ { id: 21, environment: "production", created_at: "2026-10-08T18:00:00Z",
                                                         creator: { login: "vercel[bot]" } } ].to_json)

      expect(described_class.deployments("tux/app", token: "t"))
        .to eq([ GithubGateway::Deployment.new(id: 21, environment: "production", created_at: "2026-10-08T18:00:00Z") ])
    end
  end

  describe "a 403" do
    let(:url) { "https://api.github.com/repos/tux/app/deployments?per_page=50" }

    it "means out of calls when GitHub says none remain" do
      stub_request(:get, url).to_return(status: 403, headers: json.merge("X-RateLimit-Remaining" => "0"), body: "{}")

      expect { described_class.deployments("tux/app", token: "t") }.to raise_error(ApplicationGateway::RateLimited) { |error|
        expect(error.status).to eq(403)
      }
    end

    it "means no access to the repo otherwise" do
      stub_request(:get, url).to_return(status: 403, headers: json.merge("X-RateLimit-Remaining" => "4999"), body: "{}")

      expect { described_class.deployments("tux/app", token: "t") }.to raise_error(ApplicationGateway::Unauthorized)
    end
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
