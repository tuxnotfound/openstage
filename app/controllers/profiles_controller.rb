class ProfilesController < ApplicationController
  def show
    @user = User.active.find_by(username: params[:username])
    unless @user
      render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
      return
    end

    @filter = params[:filter].presence_in(%w[shipped posted milestone note link]) || "all"
    base = @user.entries.visible.chronological
    filtered = @filter == "all" ? base : base.where(entry_type: @filter)
    @entries = filtered.page(params[:page]).per(25)

    @total_entries = @user.entries.visible.count
    @repos_synced  = @user.github_repos.included_repos.count
    @milestones    = @user.entries.visible.where(entry_type: :milestone).count

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
