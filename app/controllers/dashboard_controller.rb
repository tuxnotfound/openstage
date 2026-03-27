class DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @github_repos     = current_user.github_repos.order(:name)
    @last_github_sync = current_user.last_synced_at(source: :github)
  end
end
