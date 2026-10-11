class SetRenewalJob < ApplicationJob
  queue_as :default

  # The account change has already happened when this runs, so a Stripe outage
  # must not leave the plan in the wrong state: ten tries span about four
  # hours. A job that still fails shows in F4's failed-job count.
  retry_on ApplicationGateway::ServerError, ApplicationGateway::ConnectionFailed, ApplicationGateway::RateLimited,
           wait: :polynomially_longer, attempts: 10

  def perform(subscription_id, renew)
    Billing::SetRenewalService.new(subscription_id: subscription_id, renew: renew).call!
  end
end
