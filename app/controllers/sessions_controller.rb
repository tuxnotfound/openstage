class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    user = User.from_github_omniauth(auth)
    claimed_username = session.delete(:claimed_username).presence

    if user.new_record?
      # New user — pre-fill username but require confirmation
      session[:pending_user] = {
        github_uid: user.github_uid,
        github_username: user.github_username,
        github_access_token: user.github_access_token,
        github_token_scopes: user.github_token_scopes,
        display_name: user.display_name,
        avatar_url: user.avatar_url,
        email: user.email,
        proposed_username: claimed_username || user.username
      }
      redirect_to new_username_path
    elsif user.save
      session.delete(:signup_ref)
      session[:user_id] = user.id
      if user.gained_private_repo_access?
        GithubSyncJob.perform_later(user.id)
        redirect_to settings_path, notice: "Private repos connected. Syncing now. Include the ones you want on your timeline."
      else
        last_sync = user.last_synced_at(source: :github)
        GithubSyncJob.perform_later(user.id) if last_sync.nil? || last_sync < 2.hours.ago
        redirect_to dashboard_path, notice: "Welcome back, #{user.display_name}!"
      end
    else
      redirect_to root_path, alert: "Sign in failed. Please try again."
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, status: :see_other, notice: "You've been signed out."
  end

  def failure
    redirect_to root_path, alert: "GitHub authentication failed: #{params[:message]}"
  end
end
