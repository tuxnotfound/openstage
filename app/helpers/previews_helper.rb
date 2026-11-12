module PreviewsHelper
  # Whether a visitor can preview a stage before signing in: off until
  # Openstage's own GitHub token is set (GithubProfileGateway).
  def previews_on?
    GithubProfileGateway.configured?
  end
end
