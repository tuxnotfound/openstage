module DashboardHelper
  ENTRY_KINDS = { "milestone" => "Milestone", "released" => "Released", "repo_created" => "New repo",
                  "posted" => "Published", "link" => "Link", "note" => "Note" }.freeze

  # Each list of the Entries tab, by its key (EntriesSection::TABS).
  ENTRY_TABS = { "news" => "What's new", "commits" => "Commits", "hidden" => "Hidden", "private" => "Private" }.freeze

  # The mark an entry wears on the pages (Progress::TallyService::Item#badge):
  # a milestone's flag, the rocket of anything else shipped, the bubble of
  # what was published. A commit and a new repo wear none.
  def entry_badge(entry)
    return if entry.commit? || entry.repo_created?
    return :milestone if entry.milestone?

    Entry::SHIPPED_TYPES.include?(entry.entry_type) ? :shipped : :published
  end

  # An entry's kind as its row names it without a mark: a synced commit is a
  # commit, and a commit not yet on the default branch names that branch.
  def entry_kind(entry)
    return "On #{entry.branch}" if entry.branch.present?
    return "Commit" if entry.commit?

    ENTRY_KINDS.fetch(entry.entry_type.to_s, entry.entry_type.to_s.humanize)
  end

  # Its day in the builder's zone, with the year when it is not this one.
  def entry_day(entry)
    day = entry.occurred_at.in_time_zone(current_user.zone)
    day.year == Time.current.in_time_zone(current_user.zone).year ? day.strftime("%b %-d") : day.strftime("%b %-d, %Y")
  end

  # The lists always shown; Private on Pro, or while it holds an entry.
  def entry_tab_shown?(tab)
    tab.key != "private" || current_user.pro? || tab.total.positive?
  end

  # The list the tab opens on: the one asked for while it shows; else the
  # default.
  def entry_tab_active(tabs)
    asked = tabs.find { |tab| tab.key == entries_tab_key && entry_tab_shown?(tab) }
    asked ? asked.key : entry_tab_default(tabs)
  end

  # What's new while it holds an entry, else Commits.
  def entry_tab_default(tabs)
    tabs.find { |tab| tab.key == "news" }&.total&.positive? ? "news" : "commits"
  end

  # Every list's entries, the Entries tab's count.
  def entries_total(tabs)
    tabs.sum(&:total)
  end

  # A row's id in its list. A What's new row keeps the id its edit form's
  # frame targets.
  def entry_row_id(entry, list)
    list == "news" ? dom_id(entry) : dom_id(entry, list)
  end

  # The list an entry sits in, for a row drawn on its own (the edit form's
  # Cancel).
  def entry_list_of(entry)
    return "hidden" if entry.hidden?
    return "private" if entry.private_entry?

    entry.commit? ? "commits" : "news"
  end

  # What a row's buttons send besides their switch: the list they sit in and
  # the filters, which the page fills in as they change (entries_filter
  # controller), so the lists a click redraws stay as the builder left them.
  def entry_action_params(list, **switch)
    { list: list, q: entries_filter.query, repo: entries_filter.repo.to_s }.merge(switch)
  end

  # What a row's switch sends: On your stage, off to Hidden; back from
  # Hidden; public from Private.
  def entry_switch_params(list)
    case list
    when "hidden" then { hidden: false }
    when "private" then { visibility: "public" }
    else { hidden: true }
    end
  end

  # Why a row has no switch: its project is off the stage, or hides its
  # commits from visitors (Entry::HIDDEN_REPO_SQL, HIDDEN_COMMITS_SQL); in
  # the word a project's own view uses, and the way to the switch for it in
  # Projects. nil for a row with its switch. repo: the entry's, nil for none.
  def entry_lock(entry, repo)
    return unless repo

    if !repo.included?
      { words: "Project hidden", path: dashboard_path(row: repo.id), title: "Only you see #{repo.name}. Click to change it in Projects." }
    elsif entry.commit? && !repo.picks?("commits")
      { words: "Commits hidden", path: dashboard_path(project: repo.id),
        title: "Only you see the commits of #{repo.name}. Click to change it in Projects." }
    end
  end

  # The last syncs, at the foot of the Projects tab, as its script draws them.
  def sync_history(logs)
    logs.map do |log|
      { state: log.success? ? "up" : (log.failed? ? "down" : "warn"), source: log.source == "github" ? "GitHub" : log.source.capitalize,
        added: (log.entries_added if log.success? && log.entries_added.positive?), ago: "#{time_ago_in_words(log.ran_at)} ago" }
    end
  end
end
