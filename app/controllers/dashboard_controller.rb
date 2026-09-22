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

    @stats = {
      total:     current_user.entries.visible.count,
      this_week: current_user.entries.visible.where(occurred_at: 1.week.ago..).count,
      github:    current_user.entries.visible.where(source: :github).count,
      manual:    current_user.entries.visible.where(source: :manual).count
    }

    # Onboarding step 3. Shown until a badge has been rendered from anywhere,
    # which is the only honest evidence that it was actually added somewhere.
    @badge_nudge = current_user.badge_impressions.none?
    @badge_markdown = "[![openstage](#{profile_badge_url(current_user.username)})](#{profile_url(current_user.username)}?ref=badge)"

    # Points at /recap only when the week has something to say. A quiet week
    # gets no prompt, so the card never nags an empty page.
    recap = RecapDraft.for_user(current_user)
    @recap_prompt = recap unless recap.quiet?

    @sync_logs = current_user.sync_logs.order(ran_at: :desc).limit(5)

    # Analytics — free tier gets sparkline + unique visitors; Pro gets the full breakdown.
    views = current_user.profile_views
    @analytics = {
      total_views:  views.count,
      unique_7d:    views.unique_visitor_count(since: 7.days.ago),
      sparkline_7d: views.daily_counts(days: 7)
    }

    if current_user.pro?
      top_entry_counts  = current_user.entry_clicks
                            .group(:entry_id)
                            .order("count_all DESC")
                            .limit(5)
                            .count
      top_entries_by_id = Entry.where(id: top_entry_counts.keys).index_by(&:id)

      @analytics.merge!(
        sparkline_30d: views.daily_counts(days: 30),
        last_visited:  views.maximum(:viewed_at),
        top_countries: views.top_countries,
        top_referrers: views.top_referrers(limit: 5),
        top_entries:   top_entry_counts.filter_map { |id, count|
                         [top_entries_by_id[id], count] if top_entries_by_id[id]
                       }
      )
    end

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
