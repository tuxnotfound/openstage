# What the dashboard's Entries section shows: a tab per list the builder
# manages (every entry their pages list, the ones they hid, the private
# ones), a page at a time, newest first. DashboardController renders it with
# the page, a list alone into its frame as the filters change, and the next
# page for Load more; EntriesController redraws what a click on a row changed.
# Both read it here, so the two cannot drift apart.
module EntriesSection
  extend ActiveSupport::Concern

  PER_PAGE = 25
  # The lists, the one the section opens on first.
  TABS = %w[timeline hidden private].freeze

  # query, type and repo narrow the timeline; repos: the ones it can pick.
  Filter = Data.define(:query, :type, :repo, :repos) do
    def any?
      query.present? || type.present? || repo.present?
    end

    # As a URL carries them, the blank ones left out.
    def to_params
      { q: query.presence, type: type, repo: repo }.compact
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
      rows = page_after(after).to_a
      @more = rows.size > PER_PAGE
      @entries = rows.first(PER_PAGE)
    end

    def more?
      @more
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
    helper_method :entries_filter, :entries_tab_key
  end

  private

  def entries_filter
    @entries_filter ||= begin
      repos = current_user.entries.listed.repo_names
      Filter.new(query: params[:q].to_s.strip, type: params[:type].presence_in(Entry.entry_types.keys),
                 repo: params[:repo].presence_in(repos), repos: repos)
    end
  end

  # The tab the request came from or asks for; the timeline by default.
  def entries_tab_key
    params[:tab].presence_in(TABS) || TABS.first
  end

  def entries_tabs
    TABS.map { |key| entries_tab(key) }
  end

  def entries_tab(key, after: nil)
    list = entries_list(key)
    Tab.new(key: key, list: list, narrowed: (narrowed(list) if key == "timeline" && entries_filter.any?), after: after)
  end

  def entries_list(key)
    case key
    when "hidden" then current_user.entries.where(hidden: true)
    when "private" then current_user.entries.listed.where(visibility: :private_entry)
    else current_user.entries.listed
    end
  end

  # An unknown type or repo is ignored rather than emptying the list.
  def narrowed(list)
    filter = entries_filter
    list = list.where(entry_type: filter.type) if filter.type
    list = list.where(repo_name: filter.repo) if filter.repo
    filter.query.present? ? list.search(filter.query) : list
  end

  # The tab and filters a click came from, for the dashboard to open on.
  def entries_back_params
    { **entries_filter.to_params, tab: (entries_tab_key unless entries_tab_key == TABS.first) }.compact
  end

  # The last row Load more showed, as "time,id"; nil for the first page.
  def entries_cursor
    at, id = params[:before].to_s.split(",", 2)
    [ Time.iso8601(at), Integer(id, 10) ] if at && id
  rescue ArgumentError
    nil
  end
end
