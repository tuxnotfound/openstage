# Pre-fills a plain-text "here's what I shipped" post from a builder's own
# entries without deciding what mattered. The skeleton (opening line, counts,
# and the milestones/notes the user already flagged) is objective. Commits are
# offered as numbered candidates the user picks from; nothing here ranks them,
# because a "wip" commit can be the line that starts the conversation.
#
# The only filtering is merge commits and dependency-bump commits: tooling
# output rather than the user's voice, hidden by default behind a toggle.
# Reverts are NOT filtered - a revert is the user's own decision and is often
# the most honest line of the week.
#
# Deliberately unstyled: no emoji, no hashtags. The post body carries no link;
# the profile URL is offered as a suggested first reply, which is how
# link-bearing posts stay visible on X.
class RecapDraft
  # Below this many highlights + candidate commits a week has nothing worth
  # posting and we say so rather than pad a thin post.
  MINIMUM_ITEMS = 3

  # X's free tier caps a post at 280 characters and Bluesky at 300, so 280 is
  # the one budget that posts to both. Used for the counter, never to truncate.
  DEFAULT_LIMIT = 280

  COMMIT_TYPES = %w[shipped repo_created].freeze

  OPENINGS = [
    "Shipped this week:",
    "This week's build log:",
    "What I worked on this week:"
  ].freeze

  # Shapes that bots write. "bump X from A to B" is Dependabot's exact wording,
  # which keeps a hand-written "Bump version to 1.2.0" out of the filter.
  NOISE = /
    \A(?:
      merge\ (?:branch|pull\ request|remote|tag)\b
      | (?:build|chore|fix|ci)\(deps(?:-dev)?\):
      | bump\ \S+\ from\ \S+\ to\ \S+
      | update\ dependenc(?:y|ies)\b
      | \[dependabot\]
    )
  /xi

  # Squash-merge appends "(#123)" to the subject; GitHub wrote that, not the user.
  PR_SUFFIX = /\s*\(#\d+\)\z/

  Item      = Struct.new(:entry_type, :title, :repo_name, :sha, :merge, keyword_init: true)
  Candidate = Struct.new(:index, :repo, :title, :noise, keyword_init: true)

  # Entry records carry the commit SHA in external_id and no parent count, so
  # merges coming from the database are caught by message alone. GitHub-sourced
  # items built in lib/tasks/recap.rake set :merge structurally.
  def self.from_entries(entries)
    entries.map do |entry|
      Item.new(
        entry_type: entry.entry_type,
        title:      entry.title,
        repo_name:  entry.repo_name,
        sha:        entry.external_id,
        merge:      false
      )
    end
  end

  attr_reader :username, :items, :period_end, :limit, :include_noise, :days

  def initialize(username:, items:, period_end: nil, limit: DEFAULT_LIMIT, include_noise: false, days: 7)
    @username      = username
    @items         = items.to_a
    @period_end    = period_end || Date.current
    @limit         = limit
    @include_noise = include_noise
    @days          = days
  end

  def highlights
    @highlights ||= items.reject { |item| COMMIT_TYPES.include?(item.entry_type.to_s) }
  end

  def commits
    @commits ||= items.select { |item| COMMIT_TYPES.include?(item.entry_type.to_s) }
                      .uniq { |item| item.sha.presence || item.object_id }
  end

  def noise
    @noise ||= all_candidates.select(&:noise)
  end

  # Numbered over the FULL commit pool so a given number means the same commit
  # whether or not tooling commits are shown; hiding them just leaves gaps.
  def all_candidates
    @all_candidates ||= begin
      grouped = commits.group_by { |item| short_repo(item.repo_name) }
                       .sort_by { |repo, list| [ -list.size, repo ] }
      grouped.flat_map { |_repo, list| list }
             .each_with_index
             .map do |item, i|
               Candidate.new(
                 index: i + 1,
                 repo:  short_repo(item.repo_name),
                 title: clean_title(item.title),
                 noise: noise?(item)
               )
             end
    end
  end

  def candidates
    @candidates ||= include_noise ? all_candidates : all_candidates.reject(&:noise)
  end

  def candidates_by_repo
    candidates.group_by(&:repo)
  end

  def quiet?
    highlights.size + candidates.size < MINIMUM_ITEMS
  end

  def skeleton
    ([ counts_line ] + highlights.map { |item| "- #{clean_title(item.title)}" }).join("\n")
  end

  # picks are 1-based candidate indexes, rendered in the order the user typed
  # them so they can tell the story chronologically. Unknown indexes are ignored.
  def text(picks = [])
    return quiet_text if quiet?

    chosen = picks.filter_map { |i| candidates.find { |c| c.index == i } }.uniq
    return skeleton if chosen.empty?

    single_repo = candidates_by_repo.size == 1
    blocks = chosen.group_by(&:repo).map do |repo, list|
      lines = list.map { |c| "- #{c.title}" }
      # The counts line already names the repo when there is only one.
      single_repo ? lines.join("\n") : ([ repo ] + lines).join("\n")
    end

    ([ skeleton ] + blocks).join("\n\n")
  end

  def remaining(picks = [])
    limit - text(picks).length
  end

  def suggested_reply
    "Full timeline: #{profile_url}"
  end

  # Tagged so a signup arriving from a recap's first reply is attributable;
  # without this the loop Bet 3 tests can never be distinguished from direct.
  def profile_url
    "#{ENV.fetch('APP_HOST', 'https://openstage.dev')}/#{username}?ref=recap"
  end

  private

  def noise?(item)
    return true if item.merge
    NOISE.match?(item.title.to_s)
  end

  def opening
    return OPENINGS[period_end.cweek % OPENINGS.size] if days == 7
    "Last #{days} days:"
  end

  def counts_line
    return opening if candidates.empty?

    repos = candidates_by_repo.keys
    where = repos.size == 1 ? "in #{repos.first}" : "across #{repos.size} repos"
    "#{opening} #{candidates.size} #{'commit'.pluralize(candidates.size)} #{where}."
  end

  def quiet_text
    total = highlights.size + candidates.size
    "Quiet week - #{total} #{'entry'.pluralize(total)} logged. Nothing here worth a post yet."
  end

  def short_repo(repo_name)
    return "other" if repo_name.blank?
    repo_name.to_s.split("/").last.presence || "other"
  end

  def clean_title(title)
    title.to_s.lines.map(&:strip).find(&:present?).to_s.sub(PR_SUFFIX, "")
  end
end
