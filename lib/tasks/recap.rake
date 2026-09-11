namespace :recap do
  desc "Recap picker from an Openstage user's entries. rake 'recap:draft[tuxnotfound,7]' then rake 'recap:draft[tuxnotfound,7,1 4 7]'"
  task :draft, [ :username, :days, :picks ] => :environment do |_t, args|
    username = args[:username].presence || abort("Usage: rake 'recap:draft[username,days,picks]'")
    days     = (args[:days].presence || 7).to_i

    user = User.active.find_by(username: username) || abort("No active user '#{username}'")
    entries = user.entries.publicly_visible
                  .where(occurred_at: days.days.ago..)
                  .chronological

    draft = RecapDraft.new(username: user.username, items: entries, days: days,
                           include_noise: RecapTaskOutput.noise?)
    RecapTaskOutput.print(draft, picks: RecapTaskOutput.picks(args), window: "the last #{days} days")
  end

  desc "Same picker against ANY public GitHub account, no DB write. rake 'recap:preview[simonw,7]' then add picks"
  task :preview, [ :github_username, :days, :picks ] => :environment do |_t, args|
    handle = args[:github_username].presence || abort("Usage: rake 'recap:preview[github_username,days,picks]'")
    days   = (args[:days].presence || 7).to_i

    items = RecapTaskOutput.github_items(handle, days)
    abort("No public push activity for '#{handle}' in the last #{days} days") if items.empty?

    draft = RecapDraft.new(username: handle, items: items, days: days,
                           include_noise: RecapTaskOutput.noise?)
    RecapTaskOutput.print(draft, picks: RecapTaskOutput.picks(args), window: "the last #{days} days")
  end
end

# Presentation helpers for the rake tasks above. Kept out of app/services because
# nothing in the running app needs them.
module RecapTaskOutput
  RULE = "-" * 68

  module_function

  def noise?
    %w[1 true yes on].include?(ENV["NOISE"].to_s.downcase)
  end

  # Rake splits on commas, so "1,4,7" arrives as extras. Handles "1 4 7" too.
  def picks(args)
    ([ args[:picks] ] + Array(args.extras)).join(" ").scan(/\d+/).map(&:to_i)
  end

  def print(draft, picks:, window:)
    hidden = draft.include_noise ? 0 : draft.noise.size
    puts "=" * 68
    puts "RECAP for @#{draft.username}  (#{window}: #{draft.candidates.size} candidates, #{hidden} hidden)"
    puts "=" * 68
    puts

    if draft.quiet?
      puts draft.text
      puts
      diagnostics(draft, picks)
      return
    end

    puts "SKELETON  (objective: counts plus your own milestones and notes)"
    puts RULE
    puts draft.skeleton
    puts

    puts "CANDIDATES  (your commits; pick the ones worth calling out)"
    puts RULE
    draft.candidates_by_repo.each do |repo, list|
      puts "#{repo} (#{list.size})"
      list.each { |c| puts format("  [%2d] %s", c.index, c.title) }
    end
    if draft.noise.any? && !draft.include_noise
      puts "(#{draft.noise.size} tooling #{'commit'.pluralize(draft.noise.size)} hidden: merges and dependency bumps. NOISE=1 to show. Numbering is unchanged either way.)"
    end
    puts

    unknown = picks - draft.candidates.map(&:index)
    puts "(ignored unknown pick#{'s' if unknown.size > 1}: #{unknown.join(' ')})\n\n" if unknown.any?

    if picks.any?
      puts "DRAFT  (skeleton + picks #{picks.join(' ')})"
      puts RULE
      puts draft.text(picks)
      puts
    else
      puts "Re-run with picks to compose, e.g. rake \"recap:preview[#{draft.username},7,1 4 7]\""
      puts
    end

    puts "SUGGESTED FIRST REPLY"
    puts RULE
    puts draft.suggested_reply
    puts

    diagnostics(draft, picks)
  end

  def diagnostics(draft, picks)
    puts "DIAGNOSTICS  (not part of the post)"
    puts RULE
    puts "  skeleton:    #{draft.skeleton.length} chars of #{draft.limit} (#{draft.remaining} left for commits)"
    puts "  draft:       #{draft.text(picks).length} chars of #{draft.limit}#{' - OVER LIMIT' if draft.remaining(picks).negative?}" if picks.any?
    puts "  highlights:  #{draft.highlights.size} | candidates: #{draft.candidates.size} across #{draft.candidates_by_repo.size} repo(s) | hidden noise: #{draft.include_noise ? 0 : draft.noise.size}"
    puts "  picked:      #{picks.join(' ')} (rendered in the order you typed)" if picks.any?
    puts "  quiet week:  #{draft.quiet?}"
  end

  # The events API only reports which repos were pushed to (its PushEvent payload
  # carries SHAs, not messages), so messages come from a per-repo commits call.
  # That is also how GithubSyncJob reads them, which keeps this preview faithful.
  # Unauthenticated is 60 req/hr; set GITHUB_TOKEN to raise that.
  def github_items(handle, days)
    client = Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"].presence)
    cutoff = days.days.ago

    repos = push_repos(client, handle, cutoff)
    # The same commit appears under every fork the user pushed to, so dedupe by SHA.
    repos.flat_map { |repo| repo_commits(client, repo, handle, cutoff) }.uniq(&:sha)
  rescue Octokit::NotFound
    abort("GitHub user '#{handle}' not found")
  rescue Octokit::TooManyRequests
    abort("GitHub rate limit hit. Set GITHUB_TOKEN and retry.")
  end

  PER_PAGE  = 100
  # The events API caps at 300 events; commits are bounded so one slow account
  # cannot stall the task. Explicit page numbers rather than rel-link walking:
  # Sawyer's link.get does not update client.last_response, so following rels
  # re-reads the same next-link forever.
  MAX_EVENT_PAGES  = 3
  MAX_COMMIT_PAGES = 5

  def push_repos(client, handle, cutoff)
    repos = []

    (1..MAX_EVENT_PAGES).each do |page_number|
      page = client.user_public_events(handle, per_page: PER_PAGE, page: page_number)
      break if page.blank?

      page.each { |e| repos << e.repo.name if e.type == "PushEvent" && e.created_at >= cutoff }
      break if page.size < PER_PAGE || page.last.created_at < cutoff
    end

    repos.uniq
  end

  def repo_commits(client, repo, handle, cutoff)
    items = []

    (1..MAX_COMMIT_PAGES).each do |page_number|
      page = client.commits(repo, since: cutoff.iso8601, per_page: PER_PAGE, page: page_number)
      break if page.blank?

      page.each do |commit|
        next unless authored_by?(commit, handle)

        items << RecapDraft::Item.new(
          entry_type: "shipped",
          title: commit.commit.message,
          repo_name: repo,
          sha: commit.sha,
          merge: commit.parents.to_a.size > 1
        )
      end

      break if page.size < PER_PAGE
    end

    items
  rescue Octokit::TooManyRequests
    raise
  rescue Octokit::Error => e
    warn("  (skipped #{repo}: #{e.class})")
    []
  end

  # Mirrors GithubSyncJob#authored_by?: a nil author is NOT assumed to be the
  # handle, or contributors' unlinked-email commits get attributed to them.
  def authored_by?(commit, handle)
    username = handle.to_s.downcase
    return true if commit.author&.login&.downcase == username

    email = commit.commit&.author&.email.to_s.downcase
    return false if email.empty?

    email.match?(/\A(?:\d+\+)?#{Regexp.escape(username)}@users\.noreply\.github\.com\z/)
  end
end
