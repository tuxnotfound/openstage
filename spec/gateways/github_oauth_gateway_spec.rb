require "rails_helper"
require "support/github_app"

RSpec.describe GithubOauthGateway do
  include_context "with the GitHub App configured"

  let(:json) { { "Content-Type" => "application/json" } }

  describe ".user_token" do
    it "exchanges the code with the App's credentials" do
      stub_request(:post, "https://github.com/login/oauth/access_token")
        .with(body: { client_id: "Iv23test", client_secret: "app-secret", code: "abc" }.to_json)
        .to_return(status: 200, body: { access_token: "ghu_user", token_type: "bearer" }.to_json, headers: json)

      expect(described_class.user_token("abc")).to eq("ghu_user")
    end

    # GitHub answers 200 for a bad code, so the status alone would pass it as a token.
    it "raises ClientError when GitHub refuses the code" do
      stub_request(:post, "https://github.com/login/oauth/access_token")
        .to_return(status: 200, headers: json, body: {
          error: "bad_verification_code", error_description: "The code passed is incorrect or expired."
        }.to_json)

      expect { described_class.user_token("used") }
        .to raise_error(ApplicationGateway::ClientError, "The code passed is incorrect or expired.")
    end
  end
end
