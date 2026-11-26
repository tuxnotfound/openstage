# A payment provider a builder connects on Settings' Integrations tab, so
# their projects can show MRR, and disconnects there. Disconnecting deletes
# the key and everything read with it. Come from a project's Set up MRR
# (project), Connect goes on to that project's products.
class RevenueAccountsController < ApplicationController
  before_action :require_authentication
  rescue_from ApplicationGateway::Error, with: :stripe_unavailable

  def create
    service = Revenue::ConnectService.new(user: current_user, provider: params[:provider], api_key: params[:api_key].to_s.strip)
    return redirect_to(products_path || revenue_path, status: :see_other, notice: "Stripe connected.") if service.call

    redirect_to revenue_path, status: :see_other, alert: service.errors.full_messages.to_sentence
  end

  def destroy
    current_user.revenue_accounts.find(params[:id]).destroy!
    redirect_to revenue_path, status: :see_other, notice: "Stripe disconnected."
  end

  private

  # The builder's project they came from, if any. A refused key keeps it for
  # the next try.
  def project
    return @project if defined?(@project)

    @project = params[:project].presence && current_user.github_repos.find_by(id: params[:project])
  end

  def revenue_path
    settings_path(tab: "integrations", project: project&.id, anchor: "revenue")
  end

  def products_path
    edit_project_path(project, revenue: "open", anchor: "revenue") if project
  end

  def stripe_unavailable(error)
    Rails.error.report(error, handled: true)
    redirect_to revenue_path, status: :see_other, alert: "Stripe did not answer. Please try again in a minute."
  end
end
