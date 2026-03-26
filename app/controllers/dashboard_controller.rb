class DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @entries        = current_user.entries.visible.chronological
    @hidden_entries = current_user.entries.where(hidden: true).chronological
  end
end
