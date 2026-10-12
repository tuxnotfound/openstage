# GitHub's REST API, as the Openstage GitHub App (C12): read-only access to the
# private repos a builder picks when they install it.
class GithubAppGateway < ApplicationGateway
  API_VERSION = "2022-11-28".freeze
  PER_PAGE = 100

  # A repo as GitHub lists it, with the fields Openstage keeps.
  Repo = Data.define(:id, :name, :full_name, :description, :html_url, :default_branch, :private, :stargazers_count) do
    def initialize(stargazers_count: nil, **fields)
      super
    end
  end

  # The App's own credentials are wrong: a key that does not parse, or a key and
  # client ID that sign as another App. Never read as "not installed", which
  # would drop every builder's private repos.
  class Misconfigured < Error; end

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

  # Reads the installation's repos for an hour, and can never write. Raises
  # NotFound once the App is uninstalled.
  def self.installation_token(installation_id)
    post("/app/installations/#{installation_id.to_i}/access_tokens", headers: auth(app_jwt))[:token]
  rescue NotFound
    confirm_app!
    raise
  end

  # Every repo picked in an installation, as Repo values. Raises NotFound once
  # the App is uninstalled.
  def self.installation_repositories(installation_id)
    headers = auth(installation_token(installation_id))
    repos = []
    (1..).each do |page|
      body = get("/installation/repositories", query: { per_page: PER_PAGE, page: page }, headers: headers)
      repos.concat(body[:repositories].map { |repo| to_repo(repo) })
      return repos if body[:repositories].size < PER_PAGE || repos.size >= body[:total_count]
    end
  end

  # A repo by its numeric id, which survives renames, read with a builder's own
  # sign-in token. Raises NotFound for a repo that token cannot see, as a private
  # one is under the user:email scope.
  def self.repository(repo_id, token:)
    to_repo(get("/repositories/#{repo_id.to_i}", headers: auth(token)))
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

  def self.to_repo(repo)
    Repo.new(**Repo.members.to_h { |field| [ field, repo[field] ] })
  end

  # A 404 for an installation can also mean these credentials sign as another
  # App, for which no builder's installation exists. Check before any caller
  # reads it as an uninstall.
  def self.confirm_app!
    slug = get("/app", headers: auth(app_jwt))[:slug]
    raise Misconfigured, "the App key signs as #{slug}, not #{settings.slug}" unless slug == settings.slug
  end

  # Signed as the App itself. GitHub takes the client ID as issuer and caps the
  # lifetime at ten minutes; iat sits a minute back in case our clock runs ahead.
  def self.app_jwt
    now = Time.now.to_i
    JWT.encode({ iat: now - 60, exp: now + 540, iss: settings.client_id },
               OpenSSL::PKey::RSA.new(settings.private_key), "RS256")
  rescue OpenSSL::PKey::PKeyError, JWT::EncodeError => error
    raise Misconfigured, "GITHUB_APP_PRIVATE_KEY does not sign: #{error.message}"
  end
  private_class_method :settings, :base_url, :auth, :to_repo, :confirm_app!, :app_jwt
end
