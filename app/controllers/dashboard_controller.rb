class DashboardController < ApplicationController
  before_action :require_authentication

  PER_PAGE = 25

  def index
    # Paginated and searchable. This used to load every entry (178 for the
    # owner), so acting on an old one meant scrolling the whole history.
    @query       = params[:q].to_s.strip
    @type_filter = params[:type].presence_in(Entry.entry_types.keys)

    scope = current_user.entries.visible.chronological
    scope = scope.where(entry_type: @type_filter) if @type_filter
    scope = scope.search(@query) if @query.present?

    @entries        = scope.page(params[:page]).per(PER_PAGE)
    @filtered_count = scope.count
    @timeline_count = current_user.entries.visible.count
    @hidden_entries   = current_user.entries.where(hidden: true).chronological
    @private_entries  = current_user.entries.visible.where(visibility: :private_entry).chronological
    @last_github_sync = current_user.last_synced_at(source: :github)

    # The subscriber list is the builder's. Free sees how many; Pro sees who.
    @subscribers_count = current_user.subscriptions.confirmed.count
    @subscribers = current_user.pro? ? current_user.subscriptions.confirmed.order(confirmed_at: :desc) : nil

    # Onboarding step 3. Shown until a badge has been rendered from anywhere,
    # which is the only honest evidence that it was actually added somewhere.
    @badge_nudge = current_user.badge_impressions.none?
    @badge_markdown = "[![openstage](#{profile_badge_url(current_user.username)})](#{profile_url(current_user.username)}?ref=badge)"

    # Points at /recap only when the week has something to say. A quiet week
    # gets no prompt, so the card never nags an empty page.
    recap = RecapDraft.for_user(current_user)
    @recap_prompt = recap unless recap.quiet?

    @sync_logs = current_user.sync_logs.order(ran_at: :desc).limit(5)

    # Audience card: free sees 7 days of views, Pro sees 30. The breakdown by
    # entry, country and referrer lives on /analytics, not on the dashboard.
    views = current_user.profile_views
    @analytics = {
      total_views:  views.count,
      unique_7d:    views.unique_visitor_count(since: 7.days.ago),
      sparkline_7d: views.daily_counts(days: 7)
    }
    @analytics[:sparkline_30d] = views.daily_counts(days: 30) if current_user.pro?

    @show_pro_activated = params[:pro] == "activated"

    @streak      = current_user.current_streak
    @logged_today = current_user.entries.visible
                                .where(occurred_at: Date.current.all_day)
                                .exists?

    respond_to do |format|
      format.html
      # Only "Load more" (which always carries page) wants the append stream.
      # Every Turbo form that redirects here (Sync now, entry create/edit/delete)
      # also arrives accepting turbo_stream, because fetch keeps the Accept header
      # across the redirect. Serving them the stream skipped the layout, so the
      # flash only appeared on the next full load and page 1 was appended again.
      format.turbo_stream if params[:page].present?
    end
  end
end
