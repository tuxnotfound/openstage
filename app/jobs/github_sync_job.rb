class GithubSyncJob < ApplicationJob
  queue_as :default

  # How far back to fetch on the very first sync for a repo.
  INITIAL_SYNC_WINDOW = 3.months

  # Overlap window when computing `since` from last_synced_at. GitHub's
  # `since` filter uses committer date, not push date, so commits pushed
  # late (after their committer date) are otherwise missed forever.
  # Dedup via external_id makes the overlap free.
  SINCE_OVERLAP = 1.day

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user && user.github_access_token.present?

    client = Octokit::Client.new(access_token: user.github_access_token, auto_paginate: true)

    log = SyncLog.create!(user: user, source: :github, status: :running, ran_at: Time.current)
    entries_added = 0

    begin
      # Owner repos include both public and private repositories for this user.
      repos = client.repositories(type: "owner")

      repos.each do |repo_data|
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

      log.update!(status: :success, entries_added: entries_added)
      Rails.logger.info "[GithubSyncJob] user=#{user.username} repos=#{repos.size} entries_added=#{entries_added}"
    rescue => e
      log.update!(status: :failed, error_message: e.message)
      Rails.logger.error "[GithubSyncJob] user=#{user.username} error=#{e.message}"
      raise
    end
  end

  private

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
      default_branch: new_branch
    )
    repo.included = true if repo.new_record?
    repo.save!
    repo
  end

  def sync_commits(client, user, repo, private_repo: false)
    since = repo.last_synced_at ? repo.last_synced_at - SINCE_OVERLAP : INITIAL_SYNC_WINDOW.ago
    added = 0

    commits = client.commits(repo.full_name, repo.default_branch, since: since.iso8601)

    commits.each do |commit|
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

    added
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
