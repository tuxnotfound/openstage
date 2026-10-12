# Reads what the week card needs from GitHub beyond commits. Enqueued by each
# successful sync, so it follows the sync's schedule rather than keeping one.
class GithubExtrasJob < ApplicationJob
  queue_as :default

  retry_on ApplicationGateway::ServerError, ApplicationGateway::ConnectionFailed, wait: :polynomially_longer, attempts: 3

  def perform(user_id)
    user = User.active.find_by(id: user_id)
    return unless user && user.github_access_token.present?

    GithubExtras::RefreshService.new(user: user).call!
  end
end
