class DashboardController < ApplicationController
  include EntriesSection

  before_action :require_authentication

  # The activity chart opens on the last 90 days, as the drafts drew it.
  ACTIVITY_RANGE = "90d".freeze

  # The entries are paginated and searchable (EntriesSection). They used to
  # load every one (178 for the owner), so acting on an old one meant
  # scrolling the whole history.
  def index
    respond_to do |format|
      format.html do
        render_frame
        load_page unless performed?
      end
      # Only "Load more" (which always carries before) wants the append stream.
      # Every Turbo form that redirects here (Sync now, entry create) also
      # arrives accepting turbo_stream, because fetch keeps the Accept header
      # across the redirect. Serving them the stream skipped the layout, so the
      # flash only appeared on the next full load and page 1 was appended again.
      format.turbo_stream { @entries_page = entries_tab(entries_tab_key, after: entries_cursor) } if params[:before].present?
    end
  end

  private

  # A frame a click redraws alone, without the rest of the page: the
  # entries' tabs and lists as the filters change, or the tag panel as a row
  # is tagged.
  def render_frame
    case (turbo_frame_request_id if turbo_frame_request?)
    when "entries-lists" then render(partial: "dashboard/entry_lists", locals: { tabs: entries_tabs })
    when "untagged"
      back = params.slice(*ProgressHelper::PROGRESS_PARAMS).permit(*ProgressHelper::PROGRESS_PARAMS).to_h.symbolize_keys
      render partial: "dashboard/untagged", locals: { **untagged, back: back }
    end
  end

  # The entries of the last 12 months with no project, whatever window the
  # chart shows: counted alone while the panel is closed, and read with the
  # section's tally, which gives each row its tag choices, while it is open.
  def untagged
    window = Progress::Window.new(range: Progress::Window::DEFAULT, today: Time.current.in_time_zone(current_user.zone).to_date, first_activity: nil)
    count = current_user.entries.listed_on_page.highlights.untagged.where(occurred_at: window.span.first.in_time_zone(current_user.zone)..).count
    { count: count, labels: window.labels, section: (untagged_section(window) if params[:tag] == "1") }
  end

  def untagged_section(window)
    service = Progress::ComposeService.new(user: current_user, range: window.range, rolling: true)
    service.section if service.call
  end

  def load_page
    load_entry_tabs
    load_sync
    load_badge
    load_week
    @chart = activity_chart
    @activity = @chart&.section
    @untagged = untagged
    @show_pro_activated = params[:pro] == "activated"
  end

  # Without JavaScript, Load more opens the tab it came from past its last row.
  def load_entry_tabs
    @entry_tabs = EntriesSection::TABS.map { |key| entries_tab(key, after: (entries_cursor if key == entries_tab_key)) }
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
    @logged_today = current_user.entries.counted.where(occurred_at: Date.current.all_day).exists?
  end

  # The public page's chart of the builder's own work, as their visitors see
  # it, over the table of projects where they pick what visitors see. Its
  # projects param is the chart's (Progress::Filter); repo filters the entries.
  def activity_chart
    filter = Progress::Filter.from(params, repo: false)
    service = Progress::ChartService.new(user: current_user, range: filter.range || ACTIVITY_RANGE, repos: filter.projects,
                                         show: filter.show, builder: true)
    service if service.call
  end
end
