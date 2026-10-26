module DashboardHelper
  # The dashboard with one project switched on or off its chart: with every
  # project in view, switching one leaves the others; the last one stays.
  def dashboard_chart_path(kept, section, repo)
    repos = section.tally.projects.all.map(&:repo)
    now = section.filtered? ? section.selected.map(&:repo) : repos
    picked = now.include?(repo) ? now - [ repo ] : now + [ repo ]
    picked = now if picked.empty?
    picked = nil if picked.sort == repos.sort
    dashboard_path(**kept.except("repo").merge("repo" => picked).compact.symbolize_keys, anchor: "your-activity")
  end

  ENTRY_KINDS = { "milestone" => "Milestone", "released" => "Released", "repo_created" => "New repo",
                  "posted" => "Published", "link" => "Link", "note" => "Note" }.freeze

  # An entry's kind as its row names it: a synced commit is a commit, and a
  # commit not yet on the default branch names that branch.
  def entry_kind(entry)
    return "On #{entry.branch}" if entry.branch.present?
    return "Commit" if entry.entry_type == "shipped" && entry.source == "github"

    ENTRY_KINDS.fetch(entry.entry_type.to_s, entry.entry_type.to_s.humanize)
  end
end
