class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :stripe

  def stripe
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, ENV["STRIPE_WEBHOOK_SECRET"]
      )
    rescue JSON::ParserError, Stripe::SignatureVerificationError
      head :bad_request
      return
    end

    case event.type
    when "checkout.session.completed"
      handle_checkout_completed(event.data.object)
    when "customer.subscription.deleted"
      handle_subscription_deleted(event.data.object)
    when "invoice.payment_failed"
      handle_payment_failed(event.data.object)
    end

    head :ok
  end

  private

  def handle_checkout_completed(session)
    user = User.find_by(id: session.metadata["user_id"])
    return unless user

    user.update!(
      pro: true,
      stripe_customer_id: session.customer,
      stripe_subscription_id: session.subscription,
      pro_since: Time.current
    )
  end

  def handle_subscription_deleted(subscription)
    user = User.find_by(stripe_subscription_id: subscription.id)
    return unless user

    user.update!(pro: false, stripe_subscription_id: nil)
  end

  def handle_payment_failed(invoice)
    user = User.find_by(stripe_customer_id: invoice.customer)
    return unless user

    PaymentFailedMailer.notify(user).deliver_later
  end
end
