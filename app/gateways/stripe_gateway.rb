# Stripe's API, through the stripe gem, which brings its own TLS verification
# and timeouts. Its errors come out as ApplicationGateway's, so callers rescue
# one family whatever the API.
class StripeGateway < ApplicationGateway
  # The address of Stripe's page that starts a Pro subscription.
  def self.checkout_url(price:, user_id:, success_url:, cancel_url:)
    Stripe::Checkout::Session.create(mode: "subscription", line_items: [ { price: price, quantity: 1 } ],
                                     metadata: { user_id: user_id }, success_url: success_url, cancel_url: cancel_url).url
  rescue Stripe::StripeError => error
    raise translate(error)
  end

  # The address of Stripe's page where a customer manages their billing.
  def self.billing_portal_url(customer:, return_url:)
    Stripe::BillingPortal::Session.create(customer: customer, return_url: return_url).url
  rescue Stripe::StripeError => error
    raise translate(error)
  end

  # Whether a monthly plan renews at the end of the period already paid for.
  def self.set_renewal(subscription_id, renew:)
    Stripe::Subscription.update(subscription_id, { cancel_at_period_end: !renew })
    nil
  rescue Stripe::StripeError => error
    raise translate(error)
  end

  # The methods below read a builder's own Stripe account, with the key they
  # connected for MRR (RevenueAccount), never Openstage's. Each returns a page
  # of the list as hashes, and whether more follow (starting_after: the last
  # one's id).

  def self.products(api_key, **params)
    page(api_key) { |client| client.v1.products.list(params) }
  end

  def self.prices(api_key, **params)
    page(api_key) { |client| client.v1.prices.list(params) }
  end

  def self.subscriptions(api_key, **params)
    page(api_key) { |client| client.v1.subscriptions.list(params) }
  end

  def self.invoices(api_key, **params)
    page(api_key) { |client| client.v1.invoices.list(params) }
  end

  def self.page(api_key)
    list = yield Stripe::StripeClient.new(api_key)
    { data: list.data.map(&:to_hash), has_more: list.has_more }
  rescue Stripe::StripeError => error
    raise translate(error)
  end
  private_class_method :page

  # No HTTP status means the request never got an answer.
  def self.translate(error)
    status = error.http_status
    error_class = status ? error_class_for(status) : ConnectionFailed
    error_class.new(error.message, status: status, body: error.http_body)
  end
  private_class_method :translate
end
