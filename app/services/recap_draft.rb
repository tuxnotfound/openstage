# Builds a plain-text "here's what I shipped" post draft from a builder's own
# entries. Deliberately unstyled: no emoji, no hashtags, no "shipped!" voice.
# The audience punishes obviously templated posts, so this reads as a changelog
# the user edits before posting, never as something auto-published.
#
# The main text carries no link. The profile URL is offered as a suggested first
# reply instead, which is how link-bearing posts stay visible on X in 2026.
class RecapDraft
  # Below this, a week has nothing worth posting and we say so rather than
  # padding a thin post the user would be embarrassed to send.
  MINIMUM_ITEMS = 3
  MAX_COMMITS_PER_REPO = 5
  MAX_REPOS = 4

  # X's free tier caps a post at 280 characters and Bluesky at 300, so 280 is
  # the one budget that is postable on both without a per-platform variant.
  DEFAULT_LIMIT = 280

  # Progressively tighter (repos, commits-per-repo) pairs. The first combination
  # that fits the budget wins; if none do, we fall back to a counts-only summary.
  BUDGETS = [
    [ MAX_REPOS, MAX_COMMITS_PER_REPO ], [ 3, 4 ], [ 3, 3 ],
    [ 2, 3 ], [ 2, 2 ], [ 1, 3 ], [ 1, 2 ], [ 1, 1 ]
  ].freeze

  MAX_HIGHLIGHTS = 3

  COMMIT_TYPES = %w[shipped repo_created].freeze

  OPENINGS = [
    "Shipped this week:",
    "This week's build log:",
    "What I worked on this week:"
  ].freeze

  # Commits that are almost never worth reading in a recap. Counted and reported
  # by the rake task, but NOT filtered out here: whether raw commit streams read
  # as postable is exactly the question the first dogfood run has to answer.
  NOISE = /\A(merge (branch|pull request|remote)|bump |chore\(deps\)|update dependencies|revert )/i

  Item = Struct.new(:entry_type, :title, :repo_name, keyword_init: true)

  attr_reader :username, :items, :period_end, :limit

  def initialize(username:, items:, period_end: nil, limit: DEFAULT_LIMIT)
    @username   = username
    @items      = items.to_a
    @period_end = period_end || Date.current
    @limit      = limit
  end

  def quiet?
    items.size < MINIMUM_ITEMS
  end

  def text
    return quiet_text if quiet?

    BUDGETS.each do |max_repos, per_repo|
      candidate = build(max_repos: max_repos, per_repo: per_repo)
      return candidate if candidate.length <= limit
    end

    summary_text
  end

  # True when the draft had to drop detail to fit the platform limit.
  def trimmed?
    !quiet? && text != build(max_repos: MAX_REPOS, per_repo: MAX_COMMITS_PER_REPO)
  end

  def suggested_reply
    "Full timeline: #{profile_url}"
  end

  def profile_url
    "#{ENV.fetch('APP_HOST', 'https://openstage.dev')}/#{username}"
  end

  def highlights
    @highlights ||= items.reject { |item| COMMIT_TYPES.include?(item.entry_type.to_s) }
  end

  def commits
    @commits ||= items.select { |item| COMMIT_TYPES.include?(item.entry_type.to_s) }
  end

  # repo full names are noisy in a post; "owner/repo" reads better as "repo".
  def commits_by_repo
    @commits_by_repo ||= commits.group_by { |item| short_repo(item.repo_name) }
                                .sort_by { |_repo, list| -list.size }
  end

  def noisy_commit_count
    commits.count { |item| NOISE.match?(item.title.to_s) }
  end

  private

  def build(max_repos:, per_repo:)
    sections = [ opening ]
    sections << highlight_lines.join("\n") if highlights.any?
    sections += repo_blocks(max_repos: max_repos, per_repo: per_repo)
    sections.join("\n\n")
  end

  # Last resort when even one repo and one commit will not fit: state the shape
  # of the week honestly rather than emitting a truncated, meaningless post.
  def summary_text
    parts = [ "#{opening.chomp(':')}: #{commits.size} #{'commit'.pluralize(commits.size)} " \
              "across #{commits_by_repo.size} #{'repo'.pluralize(commits_by_repo.size)}." ]
    parts += highlight_lines.first(1)
    parts.join("\n")
  end

  def opening
    OPENINGS[period_end.cweek % OPENINGS.size]
  end

  def quiet_text
    "Quiet week - #{items.size} #{'entry'.pluralize(items.size)} logged. " \
      "Nothing here worth a post yet."
  end

  def highlight_lines
    highlights.first(MAX_HIGHLIGHTS).map { |item| "- #{first_line(item.title)}" }
  end

  def repo_blocks(max_repos:, per_repo:)
    shown = commits_by_repo.first(max_repos)
    blocks = shown.map do |repo, list|
      header = "#{repo} (#{list.size} #{'commit'.pluralize(list.size)})"
      lines  = list.first(per_repo).map { |item| "- #{first_line(item.title)}" }
      extra  = list.size - per_repo
      lines << "- and #{extra} more" if extra.positive?
      ([ header ] + lines).join("\n")
    end

    remaining = commits_by_repo.size - shown.size
    blocks << "Plus smaller changes in #{remaining} other #{'repo'.pluralize(remaining)}." if remaining.positive?
    blocks
  end

  def short_repo(repo_name)
    return "other" if repo_name.blank?
    repo_name.to_s.split("/").last
  end

  def first_line(title)
    title.to_s.split("\n").first.to_s.strip
  end
end
