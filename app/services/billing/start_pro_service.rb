module Billing
  # Makes a builder Pro on a subscription. The return from Stripe's page and
  # Stripe's webhook both call it, whichever comes first; the second changes
  # nothing, so pro_since stays when the plan began.
  class StartProService < ApplicationService
    attr_accessor :user, :customer_id, :subscription_id

    validates :user, :customer_id, :subscription_id, presence: true

    private

    def execute
      return if user.pro? && user.stripe_subscription_id == subscription_id

      user.update!(pro: true, stripe_customer_id: customer_id, stripe_subscription_id: subscription_id, pro_since: Time.current)
    end
  end
end
