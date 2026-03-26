class DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @entries = current_user.entries.visible.chronological
  end
end
