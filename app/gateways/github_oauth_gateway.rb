# GitHub's OAuth endpoint, for the Openstage GitHub App (C12). Installing the App
# also authorizes it, so GitHub sends a code back along with the installation.
class GithubOauthGateway < ApplicationGateway
  # The user token behind an authorization code. GitHub answers 200 even when the
  # code is wrong, expired or already used, with the reason in the body.
  def self.user_token(code)
    body = post("/login/oauth/access_token", body: { client_id: settings.client_id, client_secret: settings.client_secret, code: code })
    raise ClientError.new(body[:error_description] || body[:error], status: 200, body: body) if body[:error]

    body[:access_token]
  end

  def self.settings
    Rails.configuration.x.github_app
  end

  def self.base_url
    "https://github.com"
  end
  private_class_method :settings, :base_url
end
