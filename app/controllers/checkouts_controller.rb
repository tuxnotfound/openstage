class CheckoutsController < ApplicationController
  before_action :require_authentication

  def create
    price_id = if params[:plan] == "lifetime"
      ENV["STRIPE_LIFETIME_PRICE_ID"]
    else
      ENV["STRIPE_MONTHLY_PRICE_ID"]
    end

    session_params = {
      customer_email: current_user.github_username + "@users.noreply.github.com",
      metadata: { user_id: current_user.id },
      success_url: dashboard_url + "?pro=activated",
      cancel_url: dashboard_url
    }

    if params[:plan] == "lifetime"
      session_params[:mode] = "payment"
      session_params[:line_items] = [{ price: price_id, quantity: 1 }]
    else
      session_params[:mode] = "subscription"
      session_params[:line_items] = [{ price: price_id, quantity: 1 }]
    end

    checkout_session = Stripe::Checkout::Session.create(session_params)
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
