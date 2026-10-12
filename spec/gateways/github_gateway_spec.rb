require "rails_helper"

RSpec.describe GithubGateway do
  let(:json) { { "Content-Type" => "application/json" } }

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
end
