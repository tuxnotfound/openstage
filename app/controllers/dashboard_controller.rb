class DashboardController < ApplicationController
  include EntriesSection

  before_action :require_authentication

  # The untagged entries the tag line counts: the last 12 months.
  UNTAGGED_RANGE = "12m".freeze
  # The page's two tabs, the first the one it opens on.
  TABS = %w[projects entries].freeze

  # The entry box, then two tabs: Projects, whose script draws the list and
  # brings a project's numbers in (?project= opens them, ?row= lands on a
  # row), and Entries, paginated and searchable (EntriesSection). The tab is
  # in the address (?tab=), so a reload keeps it.
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
      format.turbo_stream { @entries_page = entries_tab(entries_tab_key || "news", after: entries_cursor) } if params[:before].present?
    end
  end

  private

  # A frame a click redraws alone, without the rest of the page: the
  # entries' lists as the filters change, or the tag panel as a row is
  # tagged.
  def render_frame
    case (turbo_frame_request_id if turbo_frame_request?)
    when "entries-lists" then render(partial: "dashboard/entry_lists", locals: { tabs: load_entry_tabs })
    when "untagged" then render partial: "dashboard/untagged", locals: { **untagged, back: { tab: "entries" } }
    end
  end

  # The entries of the last 12 months with no project: counted alone while
  # the panel is closed, and read with the section's tally, which gives each
  # row its tag choices, while it is open.
  def untagged
    window = Progress::Window.new(range: UNTAGGED_RANGE, today: Time.current.in_time_zone(current_user.zone).to_date, first_activity: nil)
    count = current_user.entries.listed_on_page.highlights.untagged.where(occurred_at: window.span.first.in_time_zone(current_user.zone)..).count
    { count: count, labels: window.labels, section: (untagged_section(window) if params[:tag] == "1") }
  end

  def untagged_section(window)
    service = Progress::ComposeService.new(user: current_user, range: window.range, rolling: true)
    service.section if service.call
  end

  def load_page
    @tab = params[:tab].presence_in(TABS) || TABS.first
    load_entry_tabs
    load_sync
    load_week
    load_open_project
    @untagged = untagged
    @show_pro_activated = params[:pro] == "activated" && current_user.pro?
  end

  # Without JavaScript, Load more opens the list it came from past its last
  # row; a mark on a chart opens the list on its entry.
  def load_entry_tabs
    @entry_tabs = EntriesSection::TABS.map { |key| entries_tab(key, after: (entries_cursor if key == entries_tab_key)) }
  end

  def load_sync
    @last_github_sync = current_user.last_synced_at(source: :github)
    @sync_logs = current_user.sync_logs.order(ran_at: :desc).limit(5)
  end

  # The week's numbers when it has something to say; a quiet week gets a
  # line, never a nag.
  def load_week
    recap = RecapDraft.for_user(current_user)
    @recap_prompt = recap unless recap.quiet?
    @streak = current_user.current_streak
  end

  # The project whose numbers the address opens, read with the page.
  def load_open_project
    repo = current_user.github_repos.find_by(id: params[:project]) if params[:project].present?
    @open_lines = Projects::Lines.new(repo, pins: (dashboard_projects.pinned_names if dashboard_projects.many?)) if repo
  end
end
