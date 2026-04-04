class OgImagesController < ApplicationController
  def show
    user = User.active.find_by(username: params[:username])
    return head :not_found unless user

    png = OgImageGenerator.call(
      user,
      entries_count:    user.entries.visible.count,
      repos_count:      user.github_repos.included_repos.count,
      milestones_count: user.entries.visible.where(entry_type: :milestone).count
    )

    expires_in 1.hour, public: true
    send_data png, type: "image/png", disposition: "inline"
  end
end
