class ProfilesController < ApplicationController
  def show
    @user = User.active.find_by(username: params[:username])
    unless @user
      render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
      return
    end

    @filter     = params[:filter].presence_in(%w[shipped posted milestone note link]) || "all"
    @repo_filter = params[:repo].presence

    base = @user.entries.visible.chronological
    base = base.where(entry_type: @filter) unless @filter == "all"
    base = base.where(repo_name: @repo_filter) if @repo_filter.present?
    @entries = base.page(params[:page]).per(25)

    @pinned_entries  = @user.entries.visible.pinned_entries.chronological
    @available_repos = @user.entries.visible.where.not(repo_name: nil).distinct.order(:repo_name).pluck(:repo_name)

    @total_entries = @user.entries.visible.count
    @repos_synced  = @user.github_repos.included_repos.count
    @milestones    = @user.entries.visible.where(entry_type: :milestone).count

    start_date = 52.weeks.ago.to_date
    raw = @user.entries.visible
               .where(occurred_at: start_date.beginning_of_day..)
               .group("DATE(occurred_at AT TIME ZONE 'UTC')")
               .count
    @heatmap_data = raw.transform_keys { |k| k.to_s }

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
