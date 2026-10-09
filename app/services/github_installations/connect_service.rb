module GithubInstallations
  # Saves the GitHub App installation a builder just made (C12), then syncs.
  # The callback's installation_id is a query param anyone can edit, so it counts
  # only when the builder's own user token lists it and it sits on their own
  # GitHub account. Organization installs are refused: the installation token
  # would list every repo in it, including ones this member cannot see.
  class ConnectService < ApplicationService
    attr_accessor :user, :code, :installation_id

    validates :user, presence: true
    validate :github_sent_an_installation

    private

    def execute
      installation = listed_installation
      if installation.nil?
        errors.add(:base, "GitHub did not list that installation for you. Sign in to GitHub as #{user.github_username} and try again.")
      elsif installation[:account_id].to_s != user.github_uid
        errors.add(:base, "Openstage was installed on #{installation[:account_login]}, not on your account #{user.github_username}. Organization accounts are not supported yet.")
      elsif user.update(github_installation_id: installation[:id])
        GithubSyncJob.perform_later(user.id)
      else
        absorb_errors(user)
      end
    rescue ApplicationGateway::ClientError
      errors.add(:base, "GitHub did not confirm the connection. Please try again.")
    end

    def listed_installation
      user_token = GithubOauthGateway.user_token(code)
      GithubAppGateway.installations(user_token).find { |installation| installation[:id].to_s == installation_id.to_s }
    end

    # No installation comes back when an organization owner has to approve the
    # install, or when the App is authorized without installing it.
    def github_sent_an_installation
      return if code.present? && installation_id.present?

      errors.add(:base, "GitHub did not send an installation back. Install Openstage on your own account from Settings.")
    end
  end
end
