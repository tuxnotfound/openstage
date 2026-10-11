# Applies a GitHub App change that GitHub reported by webhook (C12).
class GithubInstallationRefreshJob < ApplicationJob
  queue_as :default

  # GitHub never redelivers a webhook, so a passing GitHub error must not lose it.
  retry_on ApplicationGateway::ServerError, ApplicationGateway::ConnectionFailed, ApplicationGateway::RateLimited,
           wait: :polynomially_longer, attempts: 5

  def perform(user_id)
    user = User.active.find_by(id: user_id)
    return unless user

    GithubInstallations::RefreshService.new(user: user).call!
  end
end
