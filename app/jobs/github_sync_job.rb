class GithubSyncJob < ApplicationJob
  queue_as :default

  # How far back to fetch on the very first sync for a repo.
  INITIAL_SYNC_WINDOW = 3.months

  # Overlap window when computing `since` from last_synced_at. GitHub's
  # `since` filter uses committer date, not push date, so commits pushed
  # late (after their committer date) are otherwise missed forever.
  # Dedup via external_id makes the overlap free.
  SINCE_OVERLAP = 1.day

  PER_PAGE = 100
  # Backstop so a pagination bug can never loop indefinitely again.
  MAX_PAGES = 20

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user && user.github_access_token.present?

    client = Octokit::Client.new(access_token: user.github_access_token)

    log = SyncLog.create!(user: user, source: :github, status: :running, ran_at: Time.current)
    entries_added = 0
    repos_seen = 0

    begin
      # Owner repos include both public and private repositories for this user.
      fetch_repos = ->(page) { client.repositories(type: "owner", per_page: PER_PAGE, page: page) }

      each_page(fetch_repos) do |repo_page|
        repos_seen += repo_page.size

        repo_page.each do |repo_data|
          repo = sync_repo(user, repo_data)
          next unless repo.included?

          begin
            entries_added += sync_commits(client, user, repo, private_repo: repo_data.private)
            repo.update!(last_synced_at: Time.current)
          rescue Octokit::Error => e
            # Per-repo failure must not advance the watermark, or commits in the
            # gap are lost forever. Other repos continue to sync.
            Rails.logger.warn "[GithubSyncJob] skipping #{repo.full_name}: #{e.message}"
          end
        end
      end

      # Runs off our own table, not the GitHub listing, so it still works after
      # the "repo" scope is revoked and private repos vanish from the API.
      hide_excluded_private_entries(user)

      log.update!(status: :success, entries_added: entries_added)
      Rails.logger.info "[GithubSyncJob] user=#{user.username} repos=#{repos_seen} entries_added=#{entries_added}"
    rescue => e
      log.update!(status: :failed, error_message: e.message)
      Rails.logger.error "[GithubSyncJob] user=#{user.username} error=#{e.message}"
      raise
    end
  end

  private

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

  def sync_repo(user, repo_data)
    repo = GithubRepo.find_or_initialize_by(user: user, github_repo_id: repo_data.id)
    new_branch = repo_data.default_branch || "main"

    # A default-branch rename invalidates last_synced_at: the watermark was set
    # against the old branch, and commits on the new branch may predate it, so
    # a normal sync would miss them. Reset to force INITIAL_SYNC_WINDOW.
    repo.last_synced_at = nil if repo.persisted? && repo.default_branch != new_branch

    repo.assign_attributes(
      name: repo_data.name,
      full_name: repo_data.full_name,
      description: repo_data.description,
      url: repo_data.html_url,
      default_branch: new_branch,
      private_repo: !!repo_data.private
    )
    # Private repos are opt-out by default: nobody signs up expecting their
    # private commit messages to be published. The false -> true transition is
    # the moment we learn a repo is private; the old included:true default was
    # never a consent, so re-default once. A genuine later opt-in survives,
    # because the transition can only happen once.
    newly_known_private = repo.private_repo? && (repo.new_record? || repo.private_repo_changed?)
    repo.included = false if newly_known_private
    repo.included = true if repo.new_record? && !repo.private_repo?

    repo.save!
    repo
  end

  def sync_commits(client, user, repo, private_repo: false)
    since = repo.last_synced_at ? repo.last_synced_at - SINCE_OVERLAP : INITIAL_SYNC_WINDOW.ago
    added = 0

    fetch_commits = lambda do |page|
      client.commits(repo.full_name, repo.default_branch, since: since.iso8601, per_page: PER_PAGE, page: page)
    end

    each_page(fetch_commits) do |commit_page|
      commit_page.each do |commit|
        next unless authored_by?(commit, user)

        begin
          entry = Entry.find_or_initialize_by(user: user, external_id: commit.sha)
          next unless entry.new_record?

          entry.assign_attributes(
            entry_type: :shipped,
            source: :github,
            title: commit.commit.message.split("\n").first.truncate(200),
            occurred_at: commit.commit.author.date,
            # Never expose commit links for private repositories.
            url: private_repo ? nil : commit.html_url,
            repo_name: repo.full_name
          )
          entry.save!
          added += 1
        rescue ActiveRecord::RecordNotUnique
          next
        end
      end
    end

    added
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
  # fetch receives a page number and returns that page.
  def each_page(fetch)
    (1..MAX_PAGES).each do |page_number|
      page = fetch.call(page_number)
      break if page.blank?

      yield page
      break if page.size < PER_PAGE
    end
  end

  # GitHub returns `commit.author = nil` whenever the committer email isn't
  # tied to a verified account, which silently dropped legitimate commits.
  # Fall back to matching the GitHub-issued noreply email pattern.
  def authored_by?(commit, user)
    username = user.github_username.to_s.downcase
    return false if username.empty?

    login = commit.author&.login&.downcase
    return true if login == username

    email = commit.commit&.author&.email.to_s.downcase
    return false if email.empty?

    email.match?(/\A(?:\d+\+)?#{Regexp.escape(username)}@users\.noreply\.github\.com\z/)
  end
end
