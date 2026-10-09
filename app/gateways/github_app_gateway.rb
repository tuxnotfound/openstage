# GitHub's REST API, as the Openstage GitHub App (C12): read-only access to the
# private repos a builder picks when they install it.
class GithubAppGateway < ApplicationGateway
  API_VERSION = "2022-11-28".freeze
  PER_PAGE = 100

  # A repo as GitHub lists it, with the fields Openstage keeps.
  Repo = Data.define(:id, :name, :full_name, :description, :html_url, :default_branch, :private)

  def self.configured?
    settings.values_at(:slug, :client_id, :private_key).all?(&:present?)
  end

  # Where a builder installs the App and picks the repos it may read.
  def self.install_url
    "https://github.com/apps/#{settings.slug}/installations/new"
  end

  # The App's installation on a GitHub user account, as { id:, account_id: }.
  # Raises NotFound when the App is not installed there.
  def self.user_installation(github_username)
    installation = get("/users/#{ERB::Util.url_encode(github_username)}/installation", headers: auth(app_jwt))
    { id: installation[:id], account_id: installation[:account][:id] }
  end

  # Reads the installation's repos for an hour, and can never write.
  def self.installation_token(installation_id)
    post("/app/installations/#{installation_id.to_i}/access_tokens", headers: auth(app_jwt))[:token]
  end

  # Every repo picked in an installation, as Repo values. Raises NotFound once
  # the App is uninstalled.
  def self.installation_repositories(installation_id)
    headers = auth(installation_token(installation_id))
    repos = []
    (1..).each do |page|
      body = get("/installation/repositories", query: { per_page: PER_PAGE, page: page }, headers: headers)
      repos.concat(body[:repositories].map { |repo| Repo.new(**Repo.members.to_h { |field| [ field, repo[field] ] }) })
      return repos if body[:repositories].size < PER_PAGE || repos.size >= body[:total_count]
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
