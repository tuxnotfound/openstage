module Billing
  # Makes a builder Pro on the way back from Stripe's page, once Stripe confirms
  # the checkout, so Pro never waits for the webhook. The address can be opened
  # again long after, so the subscription must still be running: a cancelled
  # plan's old checkout is paid too.
  class ConfirmCheckoutService < ApplicationService
    NOT_CONFIRMED = "Stripe has not confirmed this payment yet. Pro turns on once it does, so there is no need to pay again.".freeze

    attr_accessor :user, :session_id

    validates :user, presence: true
    validates :session_id, presence: { message: NOT_CONFIRMED }

    private

    def execute
      checkout = StripeGateway.checkout_session(session_id)
      return errors.add(:base, NOT_CONFIRMED) unless confirmed?(checkout)

      starting = StartProService.new(user: user, customer_id: checkout[:customer], subscription_id: checkout[:subscription])
      starting.call
      absorb_errors(starting)
    rescue ApplicationGateway::NotFound
      errors.add(:base, NOT_CONFIRMED)
    end

    def confirmed?(checkout)
      checkout[:user_id] == user.id.to_s && checkout[:paid] && checkout[:subscription_status] == "active"
    end
  end
end
