module Billing
  # Stops a monthly plan from renewing. Runs when an account is deleted, which
  # otherwise kept billing it, and after the purge nobody would know whose card
  # it was.
  class StopRenewalService < ApplicationService
    attr_accessor :subscription_id

    validates :subscription_id, presence: true

    private

    def execute
      StripeGateway.cancel_at_period_end(subscription_id)
    rescue ApplicationGateway::NotFound
      # Already gone on Stripe: nothing left to renew.
      nil
    end
  end
end
