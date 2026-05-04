class HomeController < ApplicationController
  def index
    @recent_entries = Entry.publicly_visible
                          .joins(:user)
                          .merge(User.active)
                          .includes(:user)
                          .chronological
                          .limit(20)
  end
end
