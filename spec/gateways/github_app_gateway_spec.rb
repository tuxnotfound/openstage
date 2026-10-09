require "rails_helper"
require "support/github_app"

RSpec.describe GithubAppGateway do
  include_context "with the GitHub App configured"

  let(:json) { { "Content-Type" => "application/json" } }

  describe ".configured?" do
    it "is true once every App setting is present" do
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
      stub_request(:post, "https://api.github.com/app/installations/42/access_tokens")
        .to_return(status: 404, body: { message: "Not Found" }.to_json, headers: json)

      expect { described_class.installation_token(42) }.to raise_error(ApplicationGateway::NotFound)
    end
  end

  describe ".installations" do
    it "lists the installations the user token can see, with their accounts" do
      stub_request(:get, "https://api.github.com/user/installations?per_page=100")
        .with(headers: { "Authorization" => "Bearer ghu_user" })
        .to_return(status: 200, headers: json, body: {
          total_count: 1, installations: [ { id: 7, account: { id: 123, login: "tuxnotfound" } } ]
        }.to_json)

      expect(described_class.installations("ghu_user")).to eq([ { id: 7, account_id: 123, account_login: "tuxnotfound" } ])
    end

    it "raises Unauthorized for a dead user token" do
      stub_request(:get, "https://api.github.com/user/installations?per_page=100")
        .to_return(status: 401, body: { message: "Bad credentials" }.to_json, headers: json)

      expect { described_class.installations("ghu_dead") }.to raise_error(ApplicationGateway::Unauthorized)
    end
  end
end
