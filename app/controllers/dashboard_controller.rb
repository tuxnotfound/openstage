class DashboardController < ApplicationController
  before_action :require_authentication

  PER_PAGE = 25
  # The activity chart opens on the last 90 days, as the drafts drew it.
  ACTIVITY_RANGE = "90d".freeze

  def index
    # Paginated and searchable. This used to load every entry (178 for the
    # owner), so acting on an old one meant scrolling the whole history.
    scope = filtered_entries
    @entries        = scope.page(params[:page]).per(PER_PAGE)
    @filtered_count = scope.count

    respond_to do |format|
      format.html { load_page }
      # Only "Load more" (which always carries page) wants the append stream.
      # Every Turbo form that redirects here (Sync now, entry create/edit/delete)
      # also arrives accepting turbo_stream, because fetch keeps the Accept header
      # across the redirect. Serving them the stream skipped the layout, so the
      # flash only appeared on the next full load and page 1 was appended again.
      format.turbo_stream if params[:page].present?
    end
  end

  private

  # Search, type and repo narrow the list. Only repos with entries are offered,
  # and an unknown type or repo is ignored rather than emptying the page.
  def filtered_entries
    @query        = params[:q].to_s.strip
    @type_filter  = params[:type].presence_in(Entry.entry_types.keys)
    @repo_options = current_user.entries.visible.repo_names
    @repo_filter  = params[:repo].presence_in(@repo_options)
    @filtering    = @query.present? || @type_filter.present? || @repo_filter.present?

    scope = current_user.entries.visible.chronological
    scope = scope.where(entry_type: @type_filter) if @type_filter
    scope = scope.where(repo_name: @repo_filter) if @repo_filter
    scope = scope.search(@query) if @query.present?
    scope
  end

  def load_page
    load_entry_tabs
    load_sync
    load_badge
    load_week
    @activity = activity
    @activity_site = activity_site if @activity
    # Every repo with synced work, shown or hidden, so a hidden one can come back.
    @repos = current_user.github_repos.with_entries.order(:full_name)
    @show_pro_activated = params[:pro] == "activated"
  end

  def load_entry_tabs
    @timeline_count  = current_user.entries.visible.count
    @hidden_entries  = current_user.entries.where(hidden: true).chronological
    @private_entries = current_user.entries.visible.where(visibility: :private_entry).chronological
  end

  def load_sync
    @last_github_sync = current_user.last_synced_at(source: :github)
    @sync_logs = current_user.sync_logs.order(ran_at: :desc).limit(5)
  end

  # Onboarding step 3. Shown until a badge has been rendered from anywhere,
  # which is the only honest evidence that it was actually added somewhere.
  def load_badge
    @badge_nudge = current_user.badge_impressions.none?
    @badge_markdown = "[![openstage](#{profile_badge_url(current_user.username)})](#{profile_url(current_user.username)}?ref=badge)"
  end

  # The week's numbers when it has something to say; a quiet week gets a
  # line, never a nag.
  def load_week
    recap = RecapDraft.for_user(current_user)
    @recap_prompt = recap unless recap.quiet?
    @streak       = current_user.current_streak
    @logged_today = current_user.entries.visible.where(occurred_at: Date.current.all_day).exists?
  end

  # The site visits the builder picked for this chart, beside the commits.
  def activity_site
    gather = SiteVisits::GatherService.new(user: current_user, section: @activity, dashboard: true)
    SiteVisitsViewSerializer.new(gather, @activity) if gather.call && gather.any?
  end

  # The public page's chart of the builder's own work, every project in view.
  def activity
    service = Progress::ComposeService.new(user: current_user, rolling: true,
                                           range: params[:range].presence_in(Progress::Window::RANGES) || ACTIVITY_RANGE)
    service.section if service.call
  end
end
