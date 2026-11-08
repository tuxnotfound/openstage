module Revenue
  # Keeps the ECB's rates: all of them on the first read, then its last 90 days,
  # which also mends any night the read missed.
  class ReadRatesService < ApplicationService
    private

    # One transaction, as the ECB's file runs newest first: a first read cut
    # short would keep the recent days, and no later read would fetch the rest.
    def execute
      rates = ExchangeRate.exists? ? EcbGateway.recent_rates : EcbGateway.all_rates
      transaction do
        rates.each_slice(1000) { |slice| ExchangeRate.upsert_all(slice, unique_by: %i[currency day]) }
      end
    end
  end
end
