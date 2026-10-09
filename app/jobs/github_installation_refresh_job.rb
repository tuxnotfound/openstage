# Applies a GitHub App change that GitHub reported by webhook (C12).
class GithubInstallationRefreshJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.active.find_by(id: user_id)
    return unless user

    GithubInstallations::RefreshService.new(user: user).call!
  end
end
