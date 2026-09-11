class FeedController < ApplicationController
  # Public: the homepage already renders this same feed to signed-out visitors,
  # so the login wall only hid the one discovery surface from crawlers.
  def index
    @entries = Entry.publicly_visible
                    .joins(:user)
                    .merge(User.active)
                    .includes(:user)
                    .chronological
                    .page(params[:page])
                    .per(25)
  end
end
