module GithubPulls
  # Keeps the builder's pull requests merged lately, on the included repos they
  # committed to, so the week card can count them. Only their own: on a shared
  # repo, a teammate's pull request is not the builder's week.
  class ImportService < ApplicationService
    ACTIVE_WITHIN = 8.weeks
    SINCE = 8.weeks

    # tokens: a GithubExtras::Tokens for this user.
    attr_accessor :user, :tokens
    attr_reader :imported

    validates :user, :tokens, presence: true

    private

    def execute
      @imported = 0
      active_repos.each do |repo|
        store(repo, GithubGateway.merged_pulls(repo.full_name, token: tokens.for(repo)))
      rescue ApplicationGateway::RateLimited
        # Out of calls. The next sync carries on.
        break
      rescue ApplicationGateway::Unauthorized, ApplicationGateway::NotFound
        # This token cannot read the repo's pull requests, or the repo is gone.
        next
      end
    end

    def active_repos
      names = user.entries.where(source: :github, entry_type: :shipped, occurred_at: ACTIVE_WITHIN.ago..).select(:repo_name)
      user.github_repos.included_repos.where(full_name: names)
    end

    # The unique index keeps each pull request once, however often it is read.
    def store(repo, pulls)
      rows = pulls.filter_map do |pull|
        merged_at = Time.zone.parse(pull.merged_at.to_s)
        next if merged_at.nil? || merged_at < SINCE.ago || !pull.author_login.to_s.casecmp?(user.github_username.to_s)

        { user_id: user.id, github_repo_id: repo.id, kind: "pull_request", external_id: pull.id, occurred_at: merged_at,
          title: pull.title.to_s.truncate(200) }
      end
      return if rows.empty?

      @imported += GithubActivity.insert_all(rows, unique_by: %i[github_repo_id kind external_id], returning: :id).length
    end
  end
end
