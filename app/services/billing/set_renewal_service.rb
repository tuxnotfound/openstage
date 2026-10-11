module Billing
  # Stops a monthly plan from renewing when its account is deleted, and lets
  # it renew again when the account is restored. Without the stop, a deleted
  # account kept being billed, and after the purge nobody would know whose card
  # it was.
  class SetRenewalService < ApplicationService
    attr_accessor :subscription_id, :renew

    validates :subscription_id, presence: true
    validates :renew, inclusion: { in: [ true, false ] }

    private

    def execute
      StripeGateway.set_renewal(subscription_id, renew: renew)
    rescue ApplicationGateway::NotFound
      # Already gone on Stripe: nothing left to renew or stop.
      nil
    end
  end
end
