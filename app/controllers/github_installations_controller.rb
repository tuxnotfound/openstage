# "Connect private repos" through the Openstage GitHub App (C12). Both actions
# check GitHub for the builder's installation instead of trusting a redirect:
# GitHub does not always send the browser back.
class GithubInstallationsController < ApplicationController
  CONNECTED = "Private repos connected, read-only. Include the ones you want on your timeline.".freeze
  NOT_INSTALLED = "Openstage is not installed on your GitHub account yet.".freeze

  before_action :require_authentication
  before_action :require_github_app
  rescue_from ApplicationGateway::Error, with: :github_unavailable

  # An App already on the account connects here without leaving Openstage.
  def new
    if refresh.call && current_user.github_installation_id?
      redirect_to integrations_path, notice: CONNECTED
    else
      redirect_to GithubAppGateway.install_url, allow_other_host: true
    end
  end

  # The App's Setup URL: GitHub sends the builder here after installing and,
  # with Redirect on update, after changing the repos it may read.
  def create
    if refresh.call && current_user.github_installation_id?
      redirect_to integrations_path, notice: CONNECTED
    else
      redirect_to integrations_path, alert: refresh.errors.full_messages.to_sentence.presence || NOT_INSTALLED
    end
  end

  private

  def refresh
    @refresh ||= GithubInstallations::RefreshService.new(user: current_user)
  end

  def integrations_path
    settings_path(tab: "integrations")
  end

  def require_github_app
    head :not_found unless GithubAppGateway.configured?
  end

  def github_unavailable(error)
    Rails.error.report(error, handled: true)
    redirect_to integrations_path, alert: "GitHub did not answer. Please try again in a minute."
  end
end
