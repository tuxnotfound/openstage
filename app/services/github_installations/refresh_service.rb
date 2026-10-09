module GithubInstallations
  # Brings a builder's private repos in line with the Openstage GitHub App (C12)
  # right away, instead of at the next 2-hourly sync. Runs when the Integrations
  # tab opens, when GitHub sends the builder back, and on GitHub's installation
  # webhooks. GitHub does not always send the browser back, so the installation
  # is looked up rather than taken from a callback's query string.
  #
  # Repos newly picked on GitHub arrive excluded, and repos taken out are
  # dropped. A builder still on the older repo-scoped token keeps the private
  # repos that token lists, so for them only the full sync drops anything.
  class RefreshService < ApplicationService
    attr_accessor :user

    validates :user, presence: true

    private

    def execute
      repos = picked_repos
      repos.each { |listing| record(listing) }
      drop_unreadable(repos.map(&:id)) unless repo_scope?
    end

    def picked_repos
      known_installation_repos || found_installation_repos
    end

    def known_installation_repos
      return unless user.github_installation_id?

      GithubAppGateway.installation_repositories(user.github_installation_id)
    rescue ApplicationGateway::NotFound
      # Uninstalled on GitHub since the last look; a reinstall has a new id.
      user.update_column(:github_installation_id, nil)
      nil
    end

    # Only an installation on the builder's own account counts. An org's token
    # would list every repo in the org, including ones this member cannot see.
    def found_installation_repos
      installation = GithubAppGateway.user_installation(user.github_username)
      return [] unless installation[:account_id].to_s == user.github_uid

      user.update_column(:github_installation_id, installation[:id])
      GithubAppGateway.installation_repositories(installation[:id])
    rescue ApplicationGateway::NotFound
      []
    end

    def record(listing)
      service = GithubRepos::RecordService.new(user: user, listing: listing)
      service.call
      absorb_errors(service)
    end

    def drop_unreadable(listed_ids)
      return if errors.any?

      service = GithubRepos::DropUnreadableService.new(user: user, listed_ids: listed_ids)
      service.call
      absorb_errors(service)
    end

    def repo_scope?
      User.scopes_include_repo?(user.github_token_scopes)
    end
  end
end
