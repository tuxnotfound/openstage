# Stripe's API, through the stripe gem, which brings its own TLS verification
# and timeouts. Its errors come out as ApplicationGateway's, so callers rescue
# one family whatever the API.
class StripeGateway < ApplicationGateway
  # Ends a monthly plan at the close of the period already paid for, so it
  # never renews.
  def self.cancel_at_period_end(subscription_id)
    Stripe::Subscription.update(subscription_id, { cancel_at_period_end: true })
    nil
  rescue Stripe::StripeError => error
    raise translate(error)
  end

  # No HTTP status means the request never got an answer.
  def self.translate(error)
    status = error.http_status
    error_class = status ? error_class_for(status) : ConnectionFailed
    error_class.new(error.message, status: status, body: error.http_body)
  end
  private_class_method :translate
end
