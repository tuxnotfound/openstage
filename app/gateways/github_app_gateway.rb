# GitHub's REST API, as the Openstage GitHub App (C12): read-only access to the
# private repos a builder picks when they install it.
class GithubAppGateway < ApplicationGateway
  API_VERSION = "2022-11-28".freeze

  def self.configured?
    settings.values_at(:slug, :client_id, :client_secret, :private_key).all?(&:present?)
  end

  # Where a builder installs the App and picks the repos it may read.
  def self.install_url
    "https://github.com/apps/#{settings.slug}/installations/new"
  end

  # Reads the installation's repos for an hour, and can never write.
  def self.installation_token(installation_id)
    post("/app/installations/#{installation_id.to_i}/access_tokens", headers: auth(app_jwt))[:token]
  end

  # The installations a user token can see, as { id:, account_id:, account_login: }.
  def self.installations(user_token)
    get("/user/installations", query: { per_page: 100 }, headers: auth(user_token))[:installations].map do |installation|
      { id: installation[:id], account_id: installation[:account][:id], account_login: installation[:account][:login] }
    end
  end

  def self.settings
    Rails.configuration.x.github_app
  end

  def self.base_url
    "https://api.github.com"
  end

  def self.auth(token)
    { "Authorization" => "Bearer #{token}", "X-GitHub-Api-Version" => API_VERSION }
  end

  # Signed as the App itself. GitHub takes the client ID as issuer and caps the
  # lifetime at ten minutes; iat sits a minute back in case our clock runs ahead.
  def self.app_jwt
    now = Time.now.to_i
    JWT.encode({ iat: now - 60, exp: now + 540, iss: settings.client_id },
               OpenSSL::PKey::RSA.new(settings.private_key), "RS256")
  end
  private_class_method :settings, :base_url, :auth, :app_jwt
end
