# What the dashboard's Entries tab shows: four lists, What's new (all but
# GitHub's commits), Commits, what the builder hid, and the private ones,
# each narrowed by the same search and repo, a page at a time, newest
# first. DashboardController renders it with the page, the tabs and
# lists alone into their frame as the filters change, and the next page for
# Load more; EntriesController redraws what a click on a row changed. Both
# read it here, so the two cannot drift apart.
module EntriesSection
  extend ActiveSupport::Concern

  PER_PAGE = 10
  # The lists. What's new opens first while it holds an entry; else Commits.
  TABS = %w[news commits hidden private].freeze

  # query and repo narrow every list; repos: the ones they can pick, from
  # every list's entries.
  Filter = Data.define(:query, :repo, :repos) do
    def any?
      query.present? || repo.present?
    end

    # As a URL carries them, the blank ones left out.
    def to_params
      { q: query.presence, repo: repo }.compact
    end
  end

  # One tab: a page of its list, and how many entries the filters match in
  # it (count) of all it holds (total), each counted once asked for.
  class Tab
    attr_reader :key, :entries

    # narrowed: the list as the filters narrow it, nil when none do. after:
    # the time and id of the last row shown, for the next page.
    def initialize(key:, list:, narrowed: nil, after: nil)
      @key = key
      @list = list
      @narrowed = narrowed || list
      @filtered = !narrowed.nil?
      @after = after
      rows = page_after(after).to_a
      @more = rows.size > PER_PAGE
      @entries = rows.first(PER_PAGE)
    end

    def more?
      @more
    end

    # Whether the page starts past the newest rows: Load more without
    # JavaScript, or a mark on the chart, opened it there.
    def past_newest?
      !@after.nil?
    end

    def count
      @count ||= @filtered ? @narrowed.count : total
    end

    def total
      @total ||= @list.count
    end

    def includes?(entry)
      @narrowed.exists?(entry.id)
    end

    # Where Load more starts: past the last row, by value, so a row hidden
    # or restored above it since never shifts the next page.
    def cursor
      last = entries.last
      "#{last.occurred_at.utc.iso8601(6)},#{last.id}" if last
    end

    private

    def page_after(after)
      rows = @narrowed.reorder(occurred_at: :desc, id: :desc).limit(PER_PAGE + 1)
      after ? rows.where("(entries.occurred_at, entries.id) < (?, ?)", *after) : rows
    end
  end

  included do
    helper_method :entries_filter, :entries_tab_key, :dashboard_projects
  end

  private

  # The builder's projects as the dashboard lists them (Projects::DashboardList):
  # the Projects tab's rows, and each entry's project, its colour and whether
  # it keeps the entry off the stage. row: a project the tab opens on.
  def dashboard_projects
    @dashboard_projects ||= Projects::DashboardList.new(current_user, row: params[:row])
  end

  def entries_filter
    @entries_filter ||= begin
      repos = current_user.entries.listed.or(current_user.entries.where(hidden: true)).repo_names
      Filter.new(query: params[:q].to_s.strip, repo: params[:repo].presence_in(repos), repos: repos)
    end
  end

  # The list the request came from or asks for; nil when it names none, and
  # the page opens on What's new or Commits (DashboardHelper#entry_tab_active).
  def entries_tab_key
    params[:list].presence_in(TABS)
  end

  def entries_tabs
    TABS.map { |key| entries_tab(key) }
  end

  def entries_tab(key, after: nil)
    list = entries_list(key)
    Tab.new(key: key, list: list, narrowed: (narrowed(list) if entries_filter.any?), after: after)
  end

  def entries_list(key)
    case key
    when "hidden" then current_user.entries.where(hidden: true)
    when "private" then current_user.entries.listed.private_entry
    when "commits" then current_user.entries.listed.public_entry.commits
    else current_user.entries.listed.public_entry.where.not(source: :github, entry_type: :shipped)
    end
  end

  # An unknown repo is ignored rather than emptying the list.
  def narrowed(list)
    filter = entries_filter
    list = list.where(repo_name: filter.repo) if filter.repo
    filter.query.present? ? list.search(filter.query) : list
  end

  # The list and filters a click came from, for the dashboard to open on.
  def entries_back_params
    { **entries_filter.to_params, tab: "entries", list: entries_tab_key }.compact
  end

  # The last row Load more showed, as "time,id"; nil for the first page. A
  # mark on the chart names an entry instead (entry), so the page opens on it.
  def entries_cursor
    return entry_cursor(params[:entry]) if params[:entry].present?

    at, id = params[:before].to_s.split(",", 2)
    [ Time.iso8601(at), Integer(id, 10) ] if at && id
  rescue ArgumentError
    nil
  end

  # Just past an entry of the builder's, so it is the first row; nil for one
  # that is not theirs.
  def entry_cursor(id)
    entry = current_user.entries.find_by(id: id)
    [ entry.occurred_at, entry.id + 1 ] if entry
  end
end
