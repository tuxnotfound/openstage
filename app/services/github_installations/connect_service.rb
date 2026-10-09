module GithubInstallations
  # Saves the Openstage GitHub App installation on a builder's own GitHub account
  # (C12), then syncs. GitHub is asked, as the App, which installation sits on
  # that account, so nothing in a callback's query string is trusted. Installs
  # on organizations are never picked up: the installation token would list
  # every repo in one, including ones this member cannot see.
  class ConnectService < ApplicationService
    attr_accessor :user

    validates :user, presence: true

    private

    def execute
      installation = GithubAppGateway.user_installation(user.github_username)
      # The username is refreshed at each sign-in. If it changed on GitHub since,
      # the old name may now belong to someone else.
      if installation[:account_id].to_s != user.github_uid
        errors.add(:base, "Your GitHub username has changed. Sign out and in again, then connect.")
      elsif user.update(github_installation_id: installation[:id])
        GithubSyncJob.perform_later(user.id)
      else
        absorb_errors(user)
      end
    rescue ApplicationGateway::NotFound
      errors.add(:base, "Openstage is not installed on your GitHub account yet.")
    end
  end
end
