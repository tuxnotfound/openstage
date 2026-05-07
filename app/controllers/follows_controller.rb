class FollowsController < ApplicationController
  before_action :require_authentication

  def create
    @followee = User.active.find(params[:followee_id])
    @follow = current_user.follows_as_follower.build(followee: @followee)

    if @follow.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back(fallback_location: profile_path(@followee.username)) }
      end
    else
      redirect_back(fallback_location: profile_path(@followee.username), alert: @follow.errors.full_messages.first)
    end
  end

  def destroy
    @follow = current_user.follows_as_follower.find(params[:id])
    @followee = @follow.followee
    @follow.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back(fallback_location: profile_path(@followee.username)) }
    end
  end
end
