class ProfilesController < ApplicationController
  def show
    @user = User.active.find_by(username: params[:username])
    unless @user
      @claimed_username = params[:username]
      session[:claimed_username] = @claimed_username
      render :claim
      return
    end

    track_profile_view

    # Only the owner, only until the first sync has written its log. The page
    # polls itself (see the view) so the history appears without a reload.
    @syncing = current_user == @user && @user.sync_logs.where(source: :github).none? &&
               @user.github_access_token.present?

    @filter     = params[:filter].presence_in(%w[shipped posted milestone note link]) || "all"
    @repo_filter = params[:repo].presence

    # The list drops merge and dependency-bump commits. Counts, streak and the
    # heatmap still include them: that work happened, it is just not reading.
    base = @user.entries.publicly_visible.without_tooling_noise.chronological
    base = base.where(entry_type: @filter) unless @filter == "all"
    base = base.where(repo_name: @repo_filter) if @repo_filter.present?
    @entries = base.page(params[:page]).per(25)
    @timeline = TimelineSessions.group(@entries)

    @pinned_entries  = @user.entries.publicly_visible.pinned_entries.chronological
    @available_repos = @user.entries.publicly_visible.where.not(repo_name: nil).distinct.order(:repo_name).pluck(:repo_name)
    @has_posted_entries = @user.entries.publicly_visible.posted.exists?

    @total_entries = @user.entries.publicly_visible.count
    # Public repos only: counting private ones would disclose that they exist.
    @repos_synced  = @user.github_repos.included_repos.public_repos.count
    @milestones    = @user.entries.publicly_visible.where(entry_type: :milestone).count
    # public_activity_streak, not current_streak: the latter counts private
    # entries, so the headline number would disclose private working days that
    # the heatmap directly above it correctly omits.
    @streak        = @user.public_activity_streak

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
    return if BotDetector.bot?(request.user_agent)

    referrer = request.referer.present? ? URI.parse(request.referer).host : nil rescue nil
    ip_hash  = Digest::SHA256.hexdigest("#{request.remote_ip}#{Date.current}")
    # CF-IPCountry is set by Cloudflare (e.g. "US", "GB"). nil on non-CF setups.
    country  = request.headers["CF-IPCountry"].presence

    @user.profile_views.create!(
      viewed_at: Time.current,
      referrer:  referrer,
      ip_hash:   ip_hash,
      country:   country
    )
  end
end
