module GithubDeployments
  # Keeps the deploys of a builder's included repos they committed to lately,
  # so the week card can count them. A bot makes most deploys, so every one
  # counts, whoever made it.
  class ImportService < ApplicationService
    ACTIVE_WITHIN = 8.weeks
    SINCE = 8.weeks
    # A preview or staging deploy tries a branch out; it ships nothing. Hosts
    # name environments their own way ("Preview – app", "app-pr-12"), so one
    # of these words anywhere in the name is enough.
    NON_PRODUCTION = /(?<![a-z0-9])(preview|staging|review|develop|development|dev|test|testing|qa|pr-\d+)(?![a-z0-9])/i

    # tokens: a GithubExtras::Tokens for this user.
    attr_accessor :user, :tokens
    attr_reader :imported

    validates :user, :tokens, presence: true

    private

    def execute
      @imported = 0
      active_repos.each do |repo|
        store(repo, GithubGateway.deployments(repo.full_name, token: tokens.for(repo)))
      rescue ApplicationGateway::RateLimited
        # Out of calls. The next sync carries on.
        break
      rescue ApplicationGateway::Unauthorized, ApplicationGateway::NotFound
        # This token cannot read the repo's deployments, or the repo is gone.
        next
      end
    end

    def active_repos
      names = user.entries.where(source: :github, entry_type: :shipped, occurred_at: ACTIVE_WITHIN.ago..).select(:repo_name)
      user.github_repos.included_repos.where(full_name: names)
    end

    # The unique index keeps each deploy once, however often it is read.
    def store(repo, deployments)
      rows = deployments.filter_map do |deployment|
        created_at = Time.zone.parse(deployment.created_at.to_s)
        next if created_at.nil? || created_at < SINCE.ago || NON_PRODUCTION.match?(deployment.environment.to_s)

        { user_id: user.id, github_repo_id: repo.id, kind: "deployment", external_id: deployment.id, occurred_at: created_at,
          environment: deployment.environment.to_s.truncate(200) }
      end
      return if rows.empty?

      @imported += GithubActivity.insert_all(rows, unique_by: %i[github_repo_id kind external_id], returning: :id).length
    end
  end
end
