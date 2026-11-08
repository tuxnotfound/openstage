class ReadRevenueJob < ApplicationJob
  queue_as :default

  # Stripe's outages and rate limits pass. A key revoked or gone fails nothing:
  # Revenue::ReadService records it.
  retry_on ApplicationGateway::ServerError, ApplicationGateway::ConnectionFailed, ApplicationGateway::RateLimited,
           wait: :polynomially_longer, attempts: 10

  def perform(account_id)
    account = RevenueAccount.find_by(id: account_id)
    Revenue::ReadService.new(account: account).call! if account
  end
end
