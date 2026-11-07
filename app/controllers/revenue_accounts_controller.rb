# A payment provider a builder connects on Settings' Integrations tab, so
# their projects can show MRR, and disconnects there. Disconnecting deletes
# the key and everything read with it.
class RevenueAccountsController < ApplicationController
  before_action :require_authentication
  rescue_from ApplicationGateway::Error, with: :stripe_unavailable

  def create
    service = Revenue::ConnectService.new(user: current_user, provider: params[:provider], api_key: params[:api_key].to_s.strip)
    flash_message = service.call ? { notice: "Stripe connected." } : { alert: service.errors.full_messages.to_sentence }
    redirect_to revenue_path, status: :see_other, **flash_message
  end

  def destroy
    current_user.revenue_accounts.find(params[:id]).destroy!
    redirect_to revenue_path, status: :see_other, notice: "Stripe disconnected."
  end

  private

  def revenue_path
    settings_path(tab: "integrations", anchor: "revenue")
  end

  def stripe_unavailable(error)
    Rails.error.report(error, handled: true)
    redirect_to revenue_path, status: :see_other, alert: "Stripe did not answer. Please try again in a minute."
  end
end
