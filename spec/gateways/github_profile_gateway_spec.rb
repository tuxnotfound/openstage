require "rails_helper"

RSpec.describe GithubProfileGateway do
  let(:url) { "https://api.github.com/graphql" }
  let(:json) { { "Content-Type" => "application/json" } }

  around do |example|
    config = Rails.configuration.x
    config.github_profile_token = "preview-token"
    example.run
  ensure
    config.github_profile_token = nil
  end

  def contribution(name, nodes, private: false)
    { repository: { nameWithOwner: "ada/#{name}", name: name, description: "About #{name}", url: "https://github.com/ada/#{name}",
                    homepageUrl: "", isArchived: false, isPrivate: private },
      contributions: { nodes: nodes.map { |at, count| { occurredAt: at, commitCount: count } } } }
  end

  def user(contributions, private_count: 0)
    { id: "U_ada", login: "ada", name: "Ada Lovelace", avatarUrl: "https://avatars.githubusercontent.com/u/2", bio: "", websiteUrl: nil,
      contributionsCollection: { restrictedContributionsCount: private_count, commitContributionsByRepository: contributions } }
  end

  describe ".configured?" do
    it "is true with a token" do
      expect(described_class).to be_configured
    end

    it "is false without one" do
      Rails.configuration.x.github_profile_token = nil
      expect(described_class).not_to be_configured
    end
  end

  describe ".profile" do
    # One request per span of at most 90 days, each answering its own days.
    def answer_by_span(spans)
      stub_request(:post, url).with(headers: { "Authorization" => "Bearer preview-token" }).to_return do |request|
        from = JSON.parse(request.body).dig("variables", "from")
        { status: 200, headers: json, body: { data: { user: user(spans.fetch(from.first(10), [])) } }.to_json }
      end
    end

    it "reads each span in its own request and sums a repo's days across them" do
      answer_by_span(
        "2026-01-01" => [ contribution("engine", [ [ "2026-01-02T08:00:00Z", 3 ] ]) ],
        "2026-04-01" => [ contribution("engine", [ [ "2026-04-03T08:00:00Z", 2 ] ]), contribution("notes", [ [ "2026-04-05T08:00:00Z", 1 ] ]) ]
      )

      profile = described_class.profile("ada", from: Date.new(2026, 1, 1), to: Date.new(2026, 4, 10))

      expect(WebMock).to have_requested(:post, url).twice
      expect(profile).to have_attributes(id: "U_ada", login: "ada", name: "Ada Lovelace", bio: nil, website: nil)
      engine = profile.repos.find { |repo| repo.name == "engine" }
      expect(engine.days).to eq(Date.new(2026, 1, 2) => 3, Date.new(2026, 4, 3) => 2)
      expect(profile.repos.map(&:full_name)).to contain_exactly("ada/engine", "ada/notes")
    end

    # GitHub shares the count only when they chose to show it on their profile.
    it "sums the private contributions GitHub counts in each span" do
      stub_request(:post, url).to_return do |request|
        from = JSON.parse(request.body).dig("variables", "from")
        { status: 200, headers: json, body: { data: { user: user([], private_count: from.start_with?("2026-01") ? 40 : 2) } }.to_json }
      end

      expect(described_class.profile("ada", from: Date.new(2026, 1, 1), to: Date.new(2026, 4, 10)).private_contributions).to eq(42)
    end

    it "drops a private repo, should the token read one" do
      answer_by_span("2026-01-01" => [ contribution("secret", [ [ "2026-01-02T08:00:00Z", 9 ] ], private: true) ])

      expect(described_class.profile("ada", from: Date.new(2026, 1, 1), to: Date.new(2026, 1, 31)).repos).to be_empty
    end

    it "puts a day stamped at midnight east of UTC on that day" do
      answer_by_span("2026-01-01" => [ contribution("engine", [ [ "2026-01-04T22:00:00Z", 1 ] ]) ])

      engine = described_class.profile("ada", from: Date.new(2026, 1, 1), to: Date.new(2026, 1, 31)).repos.first
      expect(engine.days.keys).to eq([ Date.new(2026, 1, 5) ])
    end

    it "raises NotFound for a login GitHub does not know" do
      stub_request(:post, url).to_return(status: 200, headers: json, body: {
        data: { user: nil }, errors: [ { type: "NOT_FOUND", message: "Could not resolve to a User with the login of 'nobody'." } ]
      }.to_json)

      expect { described_class.profile("nobody", from: Date.new(2026, 1, 1), to: Date.new(2026, 1, 31)) }
        .to raise_error(ApplicationGateway::NotFound)
    end

    it "raises RateLimited when GitHub's allowance is spent" do
      stub_request(:post, url).to_return(status: 200, headers: json, body: { errors: [ { type: "RATE_LIMITED", message: "API rate limit exceeded" } ] }.to_json)

      expect { described_class.profile("ada", from: Date.new(2026, 1, 1), to: Date.new(2026, 1, 31)) }
        .to raise_error(ApplicationGateway::RateLimited)
    end
  end

  describe ".recent_repos" do
    def node(name, private: false, archived: false)
      { nameWithOwner: "ada/#{name}", name: name, description: "", url: "https://github.com/ada/#{name}", homepageUrl: "https://#{name}.example",
        pushedAt: "2024-04-09T10:00:00Z", isPrivate: private, isArchived: archived, primaryLanguage: { name: "Ruby" } }
    end

    it "returns the public repos they own, last updated first, none private or archived" do
      stub_request(:post, url).to_return do |request|
        expect(JSON.parse(request.body)["variables"]).to eq("login" => "ada", "count" => 6)
        { status: 200, headers: json, body: { data: { user: { repositories: { nodes: [
          node("notes"), node("secret", private: true), node("old", archived: true)
        ] } } } }.to_json }
      end

      repos = described_class.recent_repos("ada", count: 6)

      expect(repos.map(&:name)).to eq(%w[notes])
      expect(repos.first).to have_attributes(full_name: "ada/notes", description: nil, homepage: "https://notes.example", language: "Ruby",
                                             updated_at: Time.utc(2024, 4, 9, 10))
    end
  end

  describe ".commits" do
    def history(nodes, private: false)
      { nameWithOwner: "ada/engine", isPrivate: private,
        defaultBranchRef: { target: { history: { nodes: nodes.map { |title, at| { messageHeadline: title, authoredDate: at, url: "https://github.com/c" } } } } } }
    end

    it "returns the author's commits from every repo asked for, newest first" do
      stub_request(:post, url).to_return do |request|
        variables = JSON.parse(request.body)["variables"]
        expect(variables).to include("id" => "U_ada", "o0" => "ada", "n0" => "engine", "o1" => "ada", "n1" => "notes")
        { status: 200, headers: json, body: { data: {
          r0: history([ [ "Add the mill", "2026-11-01T10:00:00Z" ] ]),
          r1: history([ [ "Write note G", "2026-11-03T10:00:00Z" ] ]).merge(nameWithOwner: "ada/notes")
        } }.to_json }
      end

      commits = described_class.commits("U_ada", [ "ada/engine", "ada/notes" ], per_repo: 5)

      expect(commits.map(&:title)).to eq([ "Write note G", "Add the mill" ])
      expect(commits.first).to have_attributes(repo: "ada/notes", authored_at: Time.utc(2026, 11, 3, 10))
    end

    it "leaves out a private repo and one GitHub no longer has" do
      stub_request(:post, url).to_return(status: 200, headers: json, body: { data: {
        r0: history([ [ "Secret", "2026-11-01T10:00:00Z" ] ], private: true), r1: nil
      } }.to_json)

      expect(described_class.commits("U_ada", [ "ada/engine", "ada/gone" ], per_repo: 5)).to be_empty
    end
  end
end
