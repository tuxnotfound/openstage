class ProfilesController < ApplicationController
  def show
    @user = User.active.find_by(username: params[:username])
    unless @user
      return head(:not_found) unless request.format.html?

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
    @repo_filter = selected_repos.presence

    # The list drops merge and dependency-bump commits. Counts and the streak
    # still include them: that work happened, it is just not reading.
    base = @user.entries.publicly_visible.without_tooling_noise.chronological
    base = base.where(entry_type: @filter) unless @filter == "all"
    base = base.where(repo_name: @repo_filter) if @repo_filter.present?
    @entries = base.page(params[:page]).per(25)
    @timeline = TimelineSessions.group(@entries)

    @has_posted_entries = @user.entries.publicly_visible.posted.exists?

    @total_entries = @user.entries.publicly_visible.count
    # Public repos only: counting private ones would disclose that they exist.
    @repos_synced  = @user.github_repos.included_repos.public_repos.count
    @milestones    = @user.entries.publicly_visible.where(entry_type: :milestone).count
    # public_activity_streak, not current_streak: the latter counts private
    # entries, so the headline number would disclose private working days.
    @streak        = @user.public_activity_streak

    respond_to do |format|
      format.html { @progress = progress_section }
      # Only "Load more" (which always carries page) wants the append stream.
      # A Turbo form redirecting here (Subscribe) arrives accepting turbo_stream
      # too, because fetch keeps the Accept header across the redirect. Serving
      # it the stream skipped the layout, so the flash only appeared on the next
      # full load and page 1 was silently appended again. Same fix as the
      # dashboard's.
      format.turbo_stream if params[:page].present?
      # The same de-noised public list the page shows, newest 50, no counts.
      format.rss { @rss_entries = @user.entries.publicly_visible.without_tooling_noise.chronological.limit(50) }
    end
  end

  private

  # ?repo= names one project or several (repo[]=); none means all of them.
  def selected_repos
    Array(params[:repo]).map(&:to_s).compact_blank.uniq
  end

  # The progress section opens on this year; ?repo= scopes it with the timeline.
  def progress_section
    service = Progress::ComposeService.new(user: @user, range: params[:range], offset: params[:offset], repos: @repo_filter)
    service.section if service.call
  end

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
