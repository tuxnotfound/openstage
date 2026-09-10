namespace :recap do
  desc "Print a post draft from an Openstage user's own entries. Usage: rake 'recap:draft[tuxnotfound,7]'"
  task :draft, [ :username, :days ] => :environment do |_t, args|
    username = args[:username].presence || abort("Usage: rake 'recap:draft[username,days]'")
    days     = (args[:days].presence || 7).to_i

    user = User.active.find_by(username: username) || abort("No active user '#{username}'")
    entries = user.entries.publicly_visible
                  .where(occurred_at: days.days.ago..)
                  .chronological

    draft = RecapDraft.new(username: user.username, items: entries)
    RecapTaskOutput.print(draft, source: "#{entries.size} entries from the last #{days} days")
  end

  desc "Dry-run the same draft against ANY public GitHub account, no DB write. Usage: rake 'recap:preview[Sydney205,7]'"
  task :preview, [ :github_username, :days ] => :environment do |_t, args|
    handle = args[:github_username].presence || abort("Usage: rake 'recap:preview[github_username,days]'")
    days   = (args[:days].presence || 7).to_i

    items = RecapTaskOutput.github_items(handle, days)
    abort("No public push activity for '#{handle}' in the last #{days} days") if items.empty?

    draft = RecapDraft.new(username: handle, items: items)
    RecapTaskOutput.print(draft, source: "#{items.size} public GitHub commits from the last #{days} days")
  end
end

# Presentation helpers for the rake tasks above. Kept out of app/services because
# nothing in the running app needs them.
module RecapTaskOutput
  module_function

  def print(draft, source:)
    puts "=" * 68
    puts "DRAFT for @#{draft.username}  (#{source})"
    puts "=" * 68
    puts
    puts draft.text
    puts
    unless draft.quiet?
      puts "-" * 68
      puts "SUGGESTED FIRST REPLY"
      puts draft.suggested_reply
      puts
    end
    puts "-" * 68
    puts "DIAGNOSTICS (not part of the post)"
    puts "  highlights:     #{draft.highlights.size}"
    puts "  commits:        #{draft.commits.size} across #{draft.commits_by_repo.size} repo(s)"
    puts "  likely noise:   #{draft.noisy_commit_count} merge/bump commits (C4 de-noising scope)"
    puts "  quiet week:     #{draft.quiet?}"
    puts "  character count: #{draft.text.length} (limit #{draft.limit}, trimmed to fit: #{draft.trimmed?})"
  end

  # The events API only reports which repos were pushed to (its PushEvent payload
  # carries SHAs, not messages), so messages come from a per-repo commits call.
  # That is also how GithubSyncJob reads them, which keeps this preview faithful.
  # Unauthenticated is 60 req/hr; set GITHUB_TOKEN to raise that.
  def github_items(handle, days)
    client = Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"].presence)
    cutoff = days.days.ago

    repos = client.user_public_events(handle, per_page: 100)
                  .select { |event| event.type == "PushEvent" && event.created_at >= cutoff }
                  .map { |event| event.repo.name }
                  .uniq

    repos.flat_map { |repo| repo_commits(client, repo, handle, cutoff) }
  rescue Octokit::NotFound
    abort("GitHub user '#{handle}' not found")
  rescue Octokit::TooManyRequests
    abort("GitHub rate limit hit. Set GITHUB_TOKEN and retry.")
  end

  def repo_commits(client, repo, handle, cutoff)
    client.commits(repo, since: cutoff.iso8601).filter_map do |commit|
      login = commit.author&.login
      next if login.present? && login.casecmp?(handle) == false

      RecapDraft::Item.new(
        entry_type: "shipped",
        title: commit.commit.message.to_s.split("\n").first,
        repo_name: repo
      )
    end
  rescue Octokit::Error => e
    warn("  (skipped #{repo}: #{e.class})")
    []
  end
end
