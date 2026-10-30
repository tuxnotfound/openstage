module DashboardHelper
  ENTRY_KINDS = { "milestone" => "Milestone", "released" => "Released", "repo_created" => "New repo",
                  "posted" => "Published", "link" => "Link", "note" => "Note" }.freeze

  # Each tab of the Entries section: its name and the partial of its rows.
  ENTRY_TABS = { "timeline" => "Entries", "hidden" => "Hidden", "private" => "Private" }.freeze
  ENTRY_ROWS = { "timeline" => "dashboard/entry_row", "hidden" => "dashboard/hidden_row", "private" => "dashboard/private_row" }.freeze

  # An entry's kind as its row names it: a synced commit is a commit, and a
  # commit not yet on the default branch names that branch.
  def entry_kind(entry)
    return "On #{entry.branch}" if entry.branch.present?
    return "Commit" if entry.entry_type == "shipped" && entry.source == "github"

    ENTRY_KINDS.fetch(entry.entry_type.to_s, entry.entry_type.to_s.humanize)
  end

  # Hidden and Private show as tabs only while they hold an entry.
  def entry_tab_shown?(tab)
    tab.key == "timeline" || tab.total.positive?
  end

  # The tab the section opens on: the one asked for while it shows.
  def entry_tab_active(tabs)
    tabs.find { |tab| tab.key == entries_tab_key && entry_tab_shown?(tab) }&.key || "timeline"
  end

  # A row's id in its tab. A private entry is in two lists at once, and the
  # timeline's row keeps the id its edit form's frame targets.
  def entry_row_id(entry, tab)
    tab == "timeline" ? dom_id(entry) : dom_id(entry, tab)
  end

  # What a row's buttons send besides their switch: the tab they sit in and
  # the filters, which the page fills in as they change (entries_filter
  # controller), so the lists a click redraws stay as the builder left them.
  def entry_action_params(tab, **switch)
    { tab: tab, q: entries_filter.query, type: entries_filter.type.to_s, repo: entries_filter.repo.to_s }.merge(switch)
  end
end
