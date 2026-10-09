# "Connect private repos" through the Openstage GitHub App (C12). The builder
# picks repos on GitHub, and GitHub sends them back to create with the
# installation and a code that says who they are.
class GithubInstallationsController < ApplicationController
  before_action :require_authentication
  rescue_from ApplicationGateway::Error, with: :github_unavailable

  def new
    return head :not_found unless GithubAppGateway.configured?

    redirect_to GithubAppGateway.install_url, allow_other_host: true
  end

  def create
    service = GithubInstallations::ConnectService.new(
      user: current_user, code: params[:code], installation_id: params[:installation_id]
    )
    if service.call
      redirect_to settings_path, notice: "Private repos connected, read-only. Syncing now. Include the ones you want on your timeline."
    else
      redirect_to settings_path, alert: service.errors.full_messages.to_sentence
    end
  end

  private

  def github_unavailable(error)
    Rails.error.report(error, handled: true)
    redirect_to settings_path, alert: "GitHub did not answer. Please try again in a minute."
  end
end
