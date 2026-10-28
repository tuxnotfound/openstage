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

    @syncing = syncing?

    @linked = linked_entry

    @total_entries = @user.entries.publicly_visible.count
    # Public repos only: counting private ones would disclose that they exist.
    @repos_synced  = @user.github_repos.included_repos.public_repos.count
    @milestones    = @user.entries.publicly_visible.where(entry_type: :milestone).count
    # public_activity_streak, not current_streak: the latter counts private
    # entries, so the headline number would disclose private working days.
    @streak        = @user.public_activity_streak

    respond_to do |format|
      format.html { @page = gather }
      # The same de-noised public list the page reads, newest 50, no counts.
      format.rss { @rss_entries = @user.entries.publicly_visible.without_tooling_noise.chronological.limit(50) }
    end
  end

  private

  # Only the owner, only until the first sync has written its log. The page
  # polls itself (see the view) so the history appears without a reload.
  def syncing?
    current_user == @user && @user.sync_logs.where(source: :github).none? && @user.github_access_token.present?
  end

  # A link to one entry shows it at the top, wherever the page would put it.
  def linked_entry
    @user.entries.publicly_visible.find_by(id: params[:entry]) if params[:entry].present?
  end

  # The page opens on the last 12 months, commits and site visits, every
  # project; ?range=, ?show= and ?projects= pick another view (Progress::Filter),
  # and the projects scope the whole page.
  def gather
    filter = Progress::Filter.from(params)
    service = Progress::GatherService.new(user: @user, range: filter.range, repos: filter.projects, show: filter.show)
    service if service.call
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
