class DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @entries          = current_user.entries.visible.chronological
    @hidden_entries   = current_user.entries.where(hidden: true).chronological
    @last_github_sync = current_user.last_synced_at(source: :github)

    @stats = {
      total:     current_user.entries.visible.count,
      this_week: current_user.entries.visible.where(occurred_at: 1.week.ago..).count,
      github:    current_user.entries.visible.where(source: :github).count,
      manual:    current_user.entries.visible.where(source: :manual).count
    }

    @sync_logs = current_user.sync_logs.order(ran_at: :desc).limit(5)
  end
end
