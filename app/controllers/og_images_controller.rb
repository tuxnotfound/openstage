class OgImagesController < ApplicationController
  def show
    @user = User.active.find_by(username: params[:username])
    return head :not_found unless @user

    @total_entries = @user.entries.visible.count
    @repos_synced  = @user.github_repos.included_repos.count
    @milestones    = @user.entries.visible.where(entry_type: :milestone).count

    expires_in 1.hour, public: true
    render layout: false, content_type: "image/svg+xml"
  end
end
