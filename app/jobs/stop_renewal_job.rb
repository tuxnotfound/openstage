class StopRenewalJob < ApplicationJob
  queue_as :default

  # The account is already deleted when this runs, so a passing Stripe error
  # must not leave the plan renewing.
  retry_on ApplicationGateway::ServerError, ApplicationGateway::ConnectionFailed, ApplicationGateway::RateLimited,
           wait: :polynomially_longer, attempts: 5

  def perform(subscription_id)
    Billing::StopRenewalService.new(subscription_id: subscription_id).call!
  end
end
