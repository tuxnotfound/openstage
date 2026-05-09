class GithubSyncJob < ApplicationJob
  queue_as :default

  # How far back to fetch on the very first sync for a repo.
  INITIAL_SYNC_WINDOW = 3.months

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user
    client = Octokit::Client.new(access_token: user.github_access_token, auto_paginate: true)

    log = SyncLog.create!(user: user, source: :github, status: :running, ran_at: Time.current)
    entries_added = 0

    begin
      # Owner repos include both public and private repositories for this user.
      repos = client.repositories(type: "owner")

      repos.each do |repo_data|
        repo = sync_repo(user, repo_data)
        next unless repo.included?

        entries_added += sync_commits(client, user, repo, private_repo: repo_data.private)
        repo.update!(last_synced_at: Time.current)
      end

      log.update!(status: :success, entries_added: entries_added)
      Rails.logger.info "[GithubSyncJob] user=#{user.username} repos=#{repos.size} entries_added=#{entries_added}"
      GithubSyncJob.set(wait: 2.hours).perform_later(user_id)
    rescue => e
      log.update!(status: :failed, error_message: e.message)
      Rails.logger.error "[GithubSyncJob] user=#{user.username} error=#{e.message}"
      raise
    end
  end

  private

  def sync_repo(user, repo_data)
    repo = GithubRepo.find_or_initialize_by(user: user, github_repo_id: repo_data.id)
    repo.assign_attributes(
      name: repo_data.name,
      full_name: repo_data.full_name,
      description: repo_data.description,
      url: repo_data.html_url,
      default_branch: repo_data.default_branch || "main"
    )
    repo.included = true if repo.new_record?
    repo.save!
    repo
  end

  # Overlap window when computing `since` from last_synced_at. GitHub's
  # `since` filter uses committer date, not push date, so commits pushed
  # late (after their committer date) are otherwise missed forever.
  # Dedup via external_id makes the overlap free.
  SINCE_OVERLAP = 1.day

  def sync_commits(client, user, repo, private_repo: false)
    since = repo.last_synced_at ? repo.last_synced_at - SINCE_OVERLAP : INITIAL_SYNC_WINDOW.ago
    added = 0

    commits = client.commits(repo.full_name, repo.default_branch, since: since.iso8601)

    commits.each do |commit|
      # Only include commits authored by this user
      next unless commit.author&.login&.downcase == user.github_username.downcase

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
        # Race condition — another job already inserted this commit. Safe to skip.
        next
      end
    end

    added
  rescue Octokit::Error => e
    Rails.logger.warn "[GithubSyncJob] skipping #{repo.full_name}: #{e.message}"
    0
  end
end
