class DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @entries          = current_user.entries.visible.chronological
    @hidden_entries   = current_user.entries.where(hidden: true).chronological
    @github_repos     = current_user.github_repos.order(:name)
    @last_github_sync = current_user.last_synced_at(source: :github)
  end
end
