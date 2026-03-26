class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    user = User.from_github_omniauth(auth)

    if user.new_record?
      # New user — pre-fill username but require confirmation
      session[:pending_user] = {
        github_uid: user.github_uid,
        github_username: user.github_username,
        github_access_token: user.github_access_token,
        display_name: user.display_name,
        avatar_url: user.avatar_url,
        proposed_username: user.username
      }
      redirect_to new_username_path
    elsif user.save
      session[:user_id] = user.id
      GithubSyncJob.perform_later(user.id)
      redirect_to dashboard_path, notice: "Welcome back, #{user.display_name}!"
    else
      redirect_to root_path, alert: "Sign in failed. Please try again."
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "You've been signed out."
  end

  def failure
    redirect_to root_path, alert: "GitHub authentication failed: #{params[:message]}"
  end
end
