class GithubSyncJob < ApplicationJob
  queue_as :default

  # One sync per builder at a time, across workers: two at once each find a
  # commit missing and both record it, and the second fails. A sync asked for
  # while one runs waits for it. The limit lapses after the duration, should
  # a sync die holding it.
  limits_concurrency to: 1, key: ->(user_id) { user_id }, duration: 30.minutes

  # How far back to fetch on the very first sync for a repo: the span of
  # GitHub's own contribution graph. Three months left builders between
  # projects with an empty page.
  INITIAL_SYNC_WINDOW = 1.year

  # Overlap window when computing `since` from last_synced_at. GitHub's
  # `since` filter uses committer date, not push date, so commits pushed
  # late (after their committer date) are otherwise missed forever. A branch
  # merged with a merge commit keeps its commits' dates, so a one-day overlap
  # lost every commit made more than a day before its merge (C12's nine).
  # Dedup via external_id makes reading them again safe.
  SINCE_OVERLAP = 30.days

  # Deleted commits are remembered (DismissedCommit) only from this day on, so
  # the overlap stops here: reading further back would bring back a commit
  # deleted before it. It stops binding once the overlap starts after it.
  DISMISSALS_RECORDED_FROM = Time.utc(2026, 10, 12)

  # GitHub turns down a revoked token at the first call, GET /user. One 401
  # could be a blip on GitHub's side, so the token is dropped only after a day
  # with no good sync, and the fanout then stops enqueuing it. Signing in again
  # stores a new one. Neither case raises: a dead token is the builder's state,
  # not a broken job, and raising filled the failed jobs F4 counts.
  TOKEN_GRACE = 1.day

  class TokenRejected < StandardError; end

  PER_PAGE = 100
  # Backstop so a pagination bug can never loop indefinitely again.
  MAX_PAGES = 20

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user && user.github_access_token.present?

    log = SyncLog.create!(user: user, source: :github, status: :running, ran_at: Time.current)

    begin
      sync(user)
      log.update!(status: :success, entries_added: @entries_added, error_message: sync_notes(user))
      GithubExtrasJob.perform_later(user.id)
      Rails.logger.info "[GithubSyncJob] user=#{user.username} repos=#{@listed_ids.size} entries_added=#{@entries_added}"
    rescue TokenRejected
      reject_token(user, log)
    rescue => e
      log.update!(status: :failed, error_message: e.message)
      Rails.logger.error "[GithubSyncJob] user=#{user.username} error=#{e.message}"
      raise
    end
  end

  private

  def sync(user)
    @started_at = Time.current
    @entries_added = 0
    @listed_ids = []
    @skipped = []
    @dropped = []
    client = Octokit::Client.new(access_token: user.github_access_token)

    # One header read. Keeps Settings honest about private-repo access
    # without waiting for a sign-in.
    user.update_column(:github_token_scopes, token_scopes(client).join(","))

    # Every repo the user can push to, not just the ones they own. `type: "owner"`
    # silently dropped org repos and any shared project owned by a teammate,
    # so a contributor's commits to it never appeared anywhere on Openstage.
    # Only the user's own commits are imported (see authored_by?), so a shared
    # repo shows each builder their own work. GitHub rejects `type` combined
    # with `affiliation`, hence the replacement rather than an addition.
    #
    # The explicit nil matters: Octokit's signature is repositories(user = nil,
    # options = {}), so a bare options hash lands in `user` and every option is
    # dropped. GitHub then returns its default 30 repos, the short page ends
    # pagination, and any repo past #30 by name silently never syncs.
    sync_listing(client, user, lambda do |page|
      client.repositories(nil, affiliation: "owner,collaborator,organization_member", per_page: PER_PAGE, page: page)
    end)
    sync_installation(user)
    drop_unreadable_private_repos(user)

    # Runs off our own table, not the GitHub listing, so it still works after
    # the "repo" scope is revoked and private repos vanish from the API.
    hide_excluded_private_entries(user)
  end

  def token_scopes(client)
    client.scopes
  rescue Octokit::Unauthorized
    raise TokenRejected
  end

  def reject_token(user, log)
    log.update!(status: :failed, error_message: SyncLog::TOKEN_REJECTED)
    Rails.logger.warn "[GithubSyncJob] user=#{user.username} token rejected by GitHub"

    # Only the token this run read: a sign-in meanwhile may have stored a new
    # one. Tokens are encrypted, so the stored one is read back and compared
    # under a lock, not looked up by value.
    token = user.github_access_token
    user.with_lock do
      next unless user.github_access_token == token

      # The scopes go at once, or a sign-in would keep a dead repo-scoped token over its new one.
      user.update_columns(github_token_scopes: nil)
      user.update_columns(github_access_token: nil) unless (user.last_synced_at(source: :github) || user.created_at) > TOKEN_GRACE.ago
    end
  end

  # fetch receives a page number and returns that page of repos.
  def sync_listing(client, user, fetch)
    each_page(fetch) do |repo_page|
      repo_page.each { |repo_data| sync_listed_repo(client, user, repo_data) }
    end
  end

  # Private repos the builder picked in the GitHub App (C12), read with an
  # installation token. The sign-in token above keeps the public ones. The id is
  # read fresh: a Settings check or webhook may have stored a new one since this
  # job loaded the user.
  def sync_installation(user)
    installation_id = User.where(id: user.id).pick(:github_installation_id)
    return unless installation_id

    client = Octokit::Client.new(access_token: GithubAppGateway.installation_token(installation_id))
    sync_listing(client, user, ->(page) { client.list_app_installation_repositories(per_page: PER_PAGE, page: page).repositories })
  rescue ApplicationGateway::NotFound
    # Uninstalled on GitHub, or reinstalled under a new id. Forget this id unless
    # something stored a newer one, and drop nothing this run, or a reinstall
    # would lose every include. The next Settings check or webhook settles it.
    User.where(id: user.id, github_installation_id: installation_id).update_all(github_installation_id: nil)
    @listing_incomplete = true
  end

  # An incomplete listing (page cap, App not reachable) drops nothing.
  def drop_unreadable_private_repos(user)
    return if @listing_incomplete

    drop = GithubRepos::DropUnreadableService.new(user: user, listed_ids: @listed_ids, listed_at: @started_at)
    @dropped = drop.tap(&:call!).dropped
  end

  def sync_listed_repo(client, user, repo_data)
    # A repo can be on both listings: a public one picked in the App, or any
    # repo while an older repo-scoped token is still stored.
    return if @listed_ids.include?(repo_data.id)

    @listed_ids << repo_data.id
    repo = GithubRepos::RecordService.new(user: user, listing: repo_data).tap(&:call!).repo
    return unless repo.included?

    @entries_added += sync_commits(client, user, repo)
    repo.update!(last_synced_at: Time.current)
    @entries_added += sync_branches(client, user, repo) if user.branch_commits?
  rescue Octokit::Conflict
    # GitHub answers 409 while a repo has no commits yet. Nothing failed, and the
    # watermark stays unset so its first commits get the full window.
    nil
  rescue Octokit::Error, ApplicationGateway::Error => e
    # Per-repo failure must not advance the watermark, or commits in the
    # gap are lost forever. Other repos continue to sync. The gateway errors
    # come from a squash merge's pull request lookup.
    Rails.logger.warn "[GithubSyncJob] skipping #{repo.full_name}: #{e.message}"
    @skipped << repo.full_name
  end

  # A repo the user included but GitHub no longer lists (repo deleted or
  # transferred) used to leave no trace: the run said success and nothing else.
  # Same for a repo skipped on an API error, and for private repos dropped as
  # unreadable. Shown on the dashboard's sync history.
  def sync_notes(user)
    missing = user.github_repos.included_repos.where.not(github_repo_id: @listed_ids).pluck(:full_name)
    notes = []
    notes << "not returned by GitHub: #{missing.join(', ')}" if missing.any?
    notes << "no longer readable, removed: #{@dropped.join(', ')}" if @dropped.any?
    notes << "skipped: #{@skipped.join(', ')}" if @skipped.any?
    notes << "stopped at #{MAX_PAGES * PER_PAGE} commits, older ones not read: #{@capped.join(', ')}" if @capped
    notes.join("; ").presence
  end

  # A private repo the user has not opted into must not show its commits. This
  # hides rather than forcing per-entry visibility: repo inclusion owns `hidden`,
  # the user owns `visibility`. Opting the repo back in restores them.
  def hide_excluded_private_entries(user)
    names = user.github_repos.where(private_repo: true, included: false).pluck(:full_name)
    return 0 if names.empty?

    count = user.entries
                .where(source: :github, repo_name: names, hidden: false)
                .update_all(hidden: true, url: nil)

    Rails.logger.warn "[GithubSyncJob] hid #{count} entries from excluded private repos" if count.positive?
    count
  end

  def sync_commits(client, user, repo)
    since = commits_since(repo)
    added = 0

    fetch_commits = lambda do |page|
      client.commits(repo.full_name, repo.default_branch, since: since.iso8601, per_page: PER_PAGE, page: page)
    end

    capped = each_page(fetch_commits) do |commit_page|
      commit_page.each { |commit| added += 1 if record_commit(client, user, repo, commit) }
    end

    # GitHub lists newest first, so a capped read leaves out the oldest ones.
    (@capped ||= []) << repo.full_name if capped
    added
  end

  # A repo's first sync reads the full window. Later ones go SINCE_OVERLAP
  # back, but not past DISMISSALS_RECORDED_FROM, and always at least the day
  # back they went before, so a repo last synced long ago misses nothing.
  def commits_since(repo)
    last = repo.last_synced_at
    return INITIAL_SYNC_WINDOW.ago unless last

    [ [ last - SINCE_OVERLAP, DISMISSALS_RECORDED_FROM ].max, last - 1.day ].min
  end

  # True when the commit was new to the builder's page.
  def record_commit(client, user, repo, commit)
    record = GithubCommits::RecordService.new(user: user, repo: repo, commit: to_commit(commit), token: client.access_token)
    record.tap(&:call!).added
  end

  # Octokit's commit as the gateway's, so the default branch and the others
  # are recorded by the same rules.
  def to_commit(commit)
    GithubGateway::Commit.new(sha: commit.sha, message: commit.commit.message, authored_at: commit.commit.author.date,
                              html_url: commit.html_url, author_login: commit.author&.login,
                              author_email: commit.commit&.author&.email)
  end

  # Commits only on other branches, tagged with their branch. Off when the
  # builder turned branch commits off in Settings.
  def sync_branches(client, user, repo)
    GithubCommits::ImportBranchesService.new(user: user, repo: repo, token: client.access_token).tap(&:call!).added
  rescue ApplicationGateway::Error => e
    # The default branch is in and its watermark set. Unread branches keep
    # their old heads, so the next run reads them again.
    Rails.logger.warn "[GithubSyncJob] skipping #{repo.full_name} branches: #{e.message}"
    @skipped << "#{repo.full_name} (other branches)"
    0
  end

  # Yields each page of a paginated Octokit response so the previous page can
  # be GC'd before the next is fetched. `auto_paginate: true` accumulated the
  # full result set in memory, which OOM-killed the 512MB worker on users
  # with thousands of commits across many repos.
  #
  # next_link is captured immediately after each fetch, *before* yielding,
  # because the caller's per-item processing may issue other API calls that
  # overwrite client.last_response.
  # Walks paginated results by explicit page number. The previous version
  # followed rel links and re-read client.last_response afterwards, but Sawyer's
  # link.get goes through the agent without updating last_response, so the
  # next-link never advanced and a repo with more than one page looped forever.
  # Dormant in practice only because a 2-hourly sync rarely sees 100+ commits;
  # a first backfill on a busy repo would have hung the job.
  #
  # fetch receives a page number and returns that page. True when the cap
  # stopped it: a full last page means anything past it went unseen.
  def each_page(fetch)
    (1..MAX_PAGES).each do |page_number|
      page = fetch.call(page_number)
      return false if page.blank?

      yield page
      return false if page.size < PER_PAGE
    end
    @listing_incomplete = true
  end
end
