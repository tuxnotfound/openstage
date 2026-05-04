class ProfilesController < ApplicationController
  def show
    @user = User.active.find_by(username: params[:username])
    unless @user
      render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
      return
    end

    track_profile_view

    @filter     = params[:filter].presence_in(%w[shipped posted milestone note link]) || "all"
    @repo_filter = params[:repo].presence

    base = @user.entries.publicly_visible.chronological
    base = base.where(entry_type: @filter) unless @filter == "all"
    base = base.where(repo_name: @repo_filter) if @repo_filter.present?
    @entries = base.page(params[:page]).per(25)

    @pinned_entries  = @user.entries.publicly_visible.pinned_entries.chronological
    @available_repos = @user.entries.publicly_visible.where.not(repo_name: nil).distinct.order(:repo_name).pluck(:repo_name)

    @total_entries = @user.entries.publicly_visible.count
    @repos_synced  = @user.github_repos.included_repos.count
    @milestones    = @user.entries.publicly_visible.where(entry_type: :milestone).count

    start_date = 52.weeks.ago.to_date
    raw = @user.entries.publicly_visible
               .where(occurred_at: start_date.beginning_of_day..)
               .group("DATE(occurred_at AT TIME ZONE 'UTC')")
               .count
    @heatmap_data = raw.transform_keys { |k| k.to_s }

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private

  def track_profile_view
    return if current_user == @user

    referrer = request.referer.present? ? URI.parse(request.referer).host : nil rescue nil
    ip_hash = Digest::SHA256.hexdigest("#{request.remote_ip}#{Date.current}")

    @user.profile_views.create!(
      viewed_at: Time.current,
      referrer: referrer,
      ip_hash: ip_hash
    )
  end
end
