class CheckoutsController < ApplicationController
  before_action :require_authentication
  rescue_from ApplicationGateway::Error, with: :stripe_unavailable

  # Pro is $7 a month, nothing else. The $49 lifetime deal ended on 2026-10-23:
  # one payment stops covering Pro once its features cost money to run. A page
  # cached from before still posts plan=lifetime; it gets the monthly plan,
  # with the price on Stripe's own page.
  def create
    url = StripeGateway.checkout_url(price: ENV["STRIPE_MONTHLY_PRICE_ID"], user_id: current_user.id,
                                     success_url: dashboard_url(pro: "activated"), cancel_url: dashboard_url)
    redirect_to url, allow_other_host: true
  end

  def billing_portal
    return redirect_to(settings_path, alert: "No billing account found.") if current_user.stripe_customer_id.blank?

    url = StripeGateway.billing_portal_url(customer: current_user.stripe_customer_id, return_url: settings_url)
    redirect_to url, allow_other_host: true
  end

  private

  # Stripe did not answer, or refused: say so where the builder clicked.
  def stripe_unavailable(error)
    Rails.error.report(error, handled: true)
    redirect_back fallback_location: pricing_path, alert: "Stripe did not answer. Try again in a minute."
  end
end
