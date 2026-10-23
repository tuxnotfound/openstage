module DashboardHelper
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
