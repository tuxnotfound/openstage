class EmbedsController < ApplicationController
  skip_forgery_protection only: :show

  def preview
    user = User.active.find_by(username: params[:username])
    return head :not_found unless user

    @script_src = profile_embed_url(user.username)
    @username = user.username
  end

  def show
    user = User.active.find_by(username: params[:username])
    return head :not_found unless user

    latest_entry = user.entries.publicly_visible.chronological.first

    @embed_payload = {
      username: user.username,
      display_name: user.display_name.presence || "@#{user.username}",
      avatar_url: user.avatar_url,
      latest_title: latest_entry&.title,
      latest_type: latest_entry&.entry_type&.humanize,
      latest_url: latest_entry&.url,
      profile_url: profile_url(user.username),
      origin_url: root_url
    }

    expires_in 30.minutes, public: true
    render :show, formats: :js
  end
end
