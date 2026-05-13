class FeedController < ApplicationController
  before_action :require_authentication

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
