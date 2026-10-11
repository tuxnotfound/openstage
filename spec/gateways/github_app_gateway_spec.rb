require "rails_helper"
require "support/github_app"

RSpec.describe GithubAppGateway do
  include_context "with the GitHub App configured"

  let(:json) { { "Content-Type" => "application/json" } }

  # GET /app answers with the App these credentials sign as.
  def signs_as(slug)
    stub_request(:get, "https://api.github.com/app").to_return(status: 200, headers: json, body: { slug: slug }.to_json)
  end

  describe ".configured?" do
    it "is true once every App setting is present" do
      expect(described_class).to be_configured
    end

    it "needs no client secret" do
      Rails.configuration.x.github_app.client_secret = nil
      expect(described_class).to be_configured
    end

    it "is false while the App is not registered" do
      Rails.configuration.x.github_app.private_key = nil
      expect(described_class).not_to be_configured
    end
  end

  describe ".install_url" do
    it "points at the App's install page" do
      expect(described_class.install_url).to eq("https://github.com/apps/openstage-test/installations/new")
    end
  end

  describe ".installation_token" do
    it "signs as the App and returns the installation token" do
      claims = nil
      stub_request(:post, "https://api.github.com/app/installations/42/access_tokens")
        .with { |request| claims = JWT.decode(request.headers["Authorization"].delete_prefix("Bearer "), GITHUB_APP_TEST_KEY.public_key, true, algorithm: "RS256").first }
        .to_return(status: 201, body: { token: "ghs_abc", expires_at: 1.hour.from_now.iso8601 }.to_json, headers: json)

      expect(described_class.installation_token(42)).to eq("ghs_abc")
      expect(claims["iss"]).to eq("Iv23test")
      expect(claims["exp"] - claims["iat"]).to be <= 600
    end

    it "raises NotFound once the App is uninstalled" do
      signs_as("openstage-test")
      stub_request(:post, "https://api.github.com/app/installations/42/access_tokens")
        .to_return(status: 404, body: { message: "Not Found" }.to_json, headers: json)

      expect { described_class.installation_token(42) }.to raise_error(ApplicationGateway::NotFound)
    end

    # Another App's key finds none of this App's installations. Read as an
    # uninstall, that would drop every builder's private repos.
    it "raises Misconfigured, not NotFound, when the credentials sign as another App" do
      signs_as("openstage-dev")
      stub_request(:post, "https://api.github.com/app/installations/42/access_tokens")
        .to_return(status: 404, body: { message: "Not Found" }.to_json, headers: json)

      expect { described_class.installation_token(42) }
        .to raise_error(GithubAppGateway::Misconfigured, /signs as openstage-dev, not openstage-test/)
    end

    it "raises Misconfigured when the private key does not parse" do
      Rails.configuration.x.github_app.private_key = "-----BEGIN RSA PRIVATE KEY-----\nnot a key\n-----END RSA PRIVATE KEY-----"

      expect { described_class.installation_token(42) }.to raise_error(GithubAppGateway::Misconfigured, /GITHUB_APP_PRIVATE_KEY/)
    end
  end

  describe ".installation_repositories" do
    def repo_json(id, private: true)
      { id: id, name: "r#{id}", full_name: "me/r#{id}", description: nil, html_url: "https://github.com/me/r#{id}",
        default_branch: "main", private: private, owner: { login: "me" } }
    end

    before do
      stub_request(:post, "https://api.github.com/app/installations/42/access_tokens")
        .to_return(status: 201, body: { token: "ghs_abc" }.to_json, headers: json)
    end

    it "reads every page with the installation token, as Repo values" do
      first = stub_request(:get, "https://api.github.com/installation/repositories?page=1&per_page=100")
        .with(headers: { "Authorization" => "Bearer ghs_abc" })
        .to_return(status: 200, headers: json, body: { total_count: 101, repositories: (1..100).map { |id| repo_json(id) } }.to_json)
      second = stub_request(:get, "https://api.github.com/installation/repositories?page=2&per_page=100")
        .to_return(status: 200, headers: json, body: { total_count: 101, repositories: [ repo_json(101, private: false) ] }.to_json)

      repos = described_class.installation_repositories(42)

      expect(first).to have_been_requested
      expect(second).to have_been_requested
      expect(repos.size).to eq(101)
      expect(repos.last).to eq(GithubAppGateway::Repo.new(id: 101, name: "r101", full_name: "me/r101", description: nil,
                                                          html_url: "https://github.com/me/r101", default_branch: "main", private: false))
    end

    it "raises NotFound once the App is uninstalled" do
      signs_as("openstage-test")
      stub_request(:post, "https://api.github.com/app/installations/42/access_tokens")
        .to_return(status: 404, body: { message: "Not Found" }.to_json, headers: json)

      expect { described_class.installation_repositories(42) }.to raise_error(ApplicationGateway::NotFound)
    end
  end

  describe ".repository" do
    it "reads a repo by id with the builder's own token" do
      stub_request(:get, "https://api.github.com/repositories/42")
        .with(headers: { "Authorization" => "Bearer gho_user" })
        .to_return(status: 200, headers: json, body: {
          id: 42, name: "tool", full_name: "me/tool", description: "d", html_url: "https://github.com/me/tool",
          default_branch: "main", private: false
        }.to_json)

      expect(described_class.repository(42, token: "gho_user")).to have_attributes(id: 42, full_name: "me/tool", private: false)
    end

    it "raises NotFound for a repo the token cannot see" do
      stub_request(:get, "https://api.github.com/repositories/42").to_return(status: 404, body: "{}", headers: json)

      expect { described_class.repository(42, token: "gho_user") }.to raise_error(ApplicationGateway::NotFound)
    end
  end

  describe ".user_installation" do
    it "finds the App's installation on an account, signed as the App" do
      stub_request(:get, "https://api.github.com/users/tuxnotfound/installation")
        .with { |request| JWT.decode(request.headers["Authorization"].delete_prefix("Bearer "), GITHUB_APP_TEST_KEY.public_key, true, algorithm: "RS256") }
        .to_return(status: 200, headers: json, body: { id: 7, account: { id: 123, login: "tuxnotfound", type: "User" } }.to_json)

      expect(described_class.user_installation("tuxnotfound")).to eq(id: 7, account_id: 123)
    end

    it "raises NotFound when the App is not installed there" do
      stub_request(:get, "https://api.github.com/users/tuxnotfound/installation")
        .to_return(status: 404, body: { message: "Not Found" }.to_json, headers: json)

      expect { described_class.user_installation("tuxnotfound") }.to raise_error(ApplicationGateway::NotFound)
    end
  end
end
