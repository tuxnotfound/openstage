class UsernamesController < ApplicationController
  before_action :require_pending_user

  def new
    @proposed_username = session[:pending_user]["proposed_username"]
  end

  def create
    pending = session[:pending_user]
    user = User.new(
      github_uid: pending["github_uid"],
      github_username: pending["github_username"],
      github_access_token: pending["github_access_token"],
      display_name: pending["display_name"],
      avatar_url: pending["avatar_url"],
      username: params[:username]
    )

    if user.save
      session.delete(:pending_user)
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: "Welcome to Openstage, #{user.display_name}!"
    else
      @proposed_username = params[:username]
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_pending_user
    redirect_to root_path unless session[:pending_user].present?
  end
end
