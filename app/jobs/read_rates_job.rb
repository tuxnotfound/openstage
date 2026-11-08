class ReadRatesJob < ApplicationJob
  queue_as :default

  retry_on ApplicationGateway::ServerError, ApplicationGateway::ConnectionFailed, wait: :polynomially_longer, attempts: 10

  def perform
    Revenue::ReadRatesService.new.call!
  end
end
