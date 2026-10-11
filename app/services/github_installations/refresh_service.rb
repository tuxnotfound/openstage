module GithubInstallations
  # Brings a builder's private repos in line with the Openstage GitHub App (C12)
  # right away, instead of at the next 2-hourly sync. Runs when the Integrations
  # tab shows the repos, when GitHub sends the builder back, and on GitHub's
  # installation webhooks. GitHub does not always send the browser back, so the
  # installation is looked up rather than taken from a callback's query string.
  #
  # Repos newly picked on GitHub arrive excluded, and repos taken out are
  # dropped. A builder still on the older repo-scoped token keeps the private
  # repos that token lists, so for them only the full sync drops anything.
  class RefreshService < ApplicationService
    RENAMED = "Your GitHub username has changed since you signed in. Sign out and in again, then connect.".freeze

    attr_accessor :user

    validates :user, presence: true

    private

    def execute
      listed_at = Time.current
      repos = picked_repos
      repos.each { |listing| record(listing) }
      return if errors.any? || repo_scope?

      listed_ids = repos.map(&:id)
      drop_unreadable(listed_ids + gone_public_ids(listed_ids, listed_at), listed_at)
    end

    def picked_repos
      known_installation_repos || found_installation_repos
    end

    def known_installation_repos
      return unless user.github_installation_id?

      GithubAppGateway.installation_repositories(user.github_installation_id)
    rescue ApplicationGateway::NotFound
      # Uninstalled on GitHub, or reinstalled under a new id. Forget this id
      # unless a webhook or another Settings check stored a newer one meanwhile,
      # and read that one if so.
      stale_id = user.github_installation_id
      User.where(id: user.id, github_installation_id: stale_id).update_all(github_installation_id: nil)
      user.reload
      known_installation_repos if user.github_installation_id? && user.github_installation_id != stale_id
    end

    # Only an installation on the builder's own account counts. An org's token
    # would list every repo in the org, including ones this member cannot see.
    def found_installation_repos
      installation = GithubAppGateway.user_installation(user.github_username)
      return renamed_username if installation[:account_id].to_s != user.github_uid

      user.update_column(:github_installation_id, installation[:id])
      GithubAppGateway.installation_repositories(installation[:id])
    rescue ApplicationGateway::NotFound
      []
    end

    # github_username is refreshed only at sign-in, and the old name may belong
    # to someone else now. Their installation is not this builder's.
    def renamed_username
      errors.add(:base, RENAMED)
      []
    end

    def record(listing)
      service = GithubRepos::RecordService.new(user: user, listing: listing)
      service.call
      absorb_errors(service)
    end

    # A private repo missing from the App's list may have gone public, which the
    # App no longer has to cover. It is recorded as public instead of dropped,
    # which would hide its commits and erase their links.
    def gone_public_ids(listed_ids, listed_at)
      missing = user.github_repos.where(private_repo: true, created_at: ...listed_at).where.not(github_repo_id: listed_ids)
      missing.pluck(:github_repo_id).select { |repo_id| recorded_as_public?(repo_id) }
    end

    def recorded_as_public?(repo_id)
      listing = GithubAppGateway.repository(repo_id, token: user.github_access_token)
      !listing.private && record(listing)
    rescue ApplicationGateway::NotFound
      false
    end

    def drop_unreadable(listed_ids, listed_at)
      return if errors.any?

      service = GithubRepos::DropUnreadableService.new(user: user, listed_ids: listed_ids, listed_at: listed_at)
      service.call
      absorb_errors(service)
    end

    def repo_scope?
      User.scopes_include_repo?(user.github_token_scopes)
    end
  end
end
