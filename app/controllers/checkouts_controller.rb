class CheckoutsController < ApplicationController
  before_action :require_authentication

  # Pro is $7 a month, nothing else. The $49 lifetime deal ended on 2026-10-23:
  # one payment stops covering Pro once its features cost money to run. A page
  # cached from before still posts plan=lifetime; it gets the monthly plan,
  # with the price on Stripe's own page.
  def create
    checkout_session = Stripe::Checkout::Session.create(
      mode: "subscription",
      line_items: [ { price: ENV["STRIPE_MONTHLY_PRICE_ID"], quantity: 1 } ],
      metadata: { user_id: current_user.id },
      success_url: dashboard_url + "?pro=activated",
      cancel_url: dashboard_url
    )
    redirect_to checkout_session.url, allow_other_host: true
  end

  def billing_portal
    unless current_user.stripe_customer_id.present?
      redirect_to settings_path, alert: "No billing account found."
      return
    end

    portal_session = Stripe::BillingPortal::Session.create(
      customer: current_user.stripe_customer_id,
      return_url: settings_url
    )
    redirect_to portal_session.url, allow_other_host: true
  end
end
