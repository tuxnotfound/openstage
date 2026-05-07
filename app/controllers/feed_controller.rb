class FeedController < ApplicationController
  before_action :require_authentication

  def index
    following_ids = current_user.following.active.pluck(:id)
    @entries = Entry.publicly_visible
                    .where(user_id: following_ids)
                    .joins(:user)
                    .merge(User.active)
                    .includes(:user)
                    .chronological
                    .page(params[:page])
                    .per(25)
    @following_count = following_ids.size
  end
end
