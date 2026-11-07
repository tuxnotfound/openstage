class ImportRevenueProductsJob < ApplicationJob
  queue_as :default

  # Stripe's outages and rate limits pass; a key revoked or gone fails for
  # good, and shows in F4's failed-job count.
  retry_on ApplicationGateway::ServerError, ApplicationGateway::ConnectionFailed, ApplicationGateway::RateLimited,
           wait: :polynomially_longer, attempts: 10

  def perform(account_id)
    account = RevenueAccount.find_by(id: account_id)
    Revenue::ImportProductsService.new(account: account).call! if account
  end
end
