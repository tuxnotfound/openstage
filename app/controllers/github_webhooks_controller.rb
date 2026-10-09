# GitHub's webhooks for the Openstage GitHub App (C12): installs, uninstalls and
# repo picks changed on GitHub apply within seconds, whether or not the builder
# comes back to Openstage. Off until GITHUB_APP_WEBHOOK_SECRET is set.
class GithubWebhooksController < ApplicationController
  EVENTS = %w[installation installation_repositories].freeze

  skip_forgery_protection
  before_action :verify_signature

  def create
    owner = installation_owner if EVENTS.include?(request.headers["X-GitHub-Event"])
    GithubInstallationRefreshJob.perform_later(owner.id) if owner
    head :accepted
  end

  private

  # GitHub signs the raw body with the webhook secret (HMAC SHA-256).
  def verify_signature
    secret = Rails.configuration.x.github_app.webhook_secret
    return head(:not_found) if secret.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, request.raw_post)}"
    signature = request.headers["X-Hub-Signature-256"].to_s
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end

  # The builder whose own account holds the installation. Installs on an
  # organization match nobody, because C12 never connects them.
  def installation_owner
    account_id = JSON.parse(request.raw_post).dig("installation", "account", "id")
    User.active.find_by(github_uid: account_id.to_s) if account_id
  end
end
