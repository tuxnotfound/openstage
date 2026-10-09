# "Connect private repos" through the Openstage GitHub App (C12). The builder
# picks repos on GitHub, which sends them back to create, the App's Setup URL.
class GithubInstallationsController < ApplicationController
  CONNECTED = "Private repos connected, read-only. Syncing now. Include the ones you want on your timeline.".freeze

  before_action :require_authentication
  rescue_from ApplicationGateway::Error, with: :github_unavailable

  # An App already on their account connects here: GitHub's page for an existing
  # installation sends nobody back.
  def new
    return head :not_found unless GithubAppGateway.configured?

    if connect.call
      redirect_to settings_path, notice: CONNECTED
    else
      redirect_to GithubAppGateway.install_url, allow_other_host: true
    end
  end

  def create
    service = connect
    if service.call
      redirect_to settings_path, notice: CONNECTED
    else
      redirect_to settings_path, alert: service.errors.full_messages.to_sentence
    end
  end

  private

  def connect
    GithubInstallations::ConnectService.new(user: current_user)
  end

  def github_unavailable(error)
    Rails.error.report(error, handled: true)
    redirect_to settings_path, alert: "GitHub did not answer. Please try again in a minute."
  end
end
