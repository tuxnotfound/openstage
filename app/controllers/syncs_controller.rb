class SyncsController < ApplicationController
  before_action :require_authentication

  def github
    last_sync = current_user.last_synced_at(source: :github)
    if last_sync && last_sync > 5.minutes.ago
      redirect_to dashboard_path, alert: "Sync already ran recently. Try again in a few minutes."
    else
      GithubSyncJob.perform_later(current_user.id)
      redirect_to dashboard_path, notice: "GitHub sync started. Your timeline will update shortly."
    end
  end
end
