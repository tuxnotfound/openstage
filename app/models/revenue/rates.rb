module Revenue
  # The ECB's rates for some currencies from a day on, to convert an amount at
  # the rate of its own day. The ECB publishes on working days, so any other day
  # takes the last rate before it, and today the newest.
  class Rates
    EURO = "eur".freeze
    # More days than the ECB goes without publishing, over Christmas.
    GAP = 10

    def self.for(currencies, from:)
      rows = ExchangeRate.where(currency: currencies - [ EURO ], day: (from - GAP)..).order(:day).pluck(:currency, :day, :per_euro)
      new(rows.group_by(&:first).transform_values { |rates| rates.map { |_, day, per_euro| [ day, per_euro.to_f ] } })
    end

    # by_currency: { currency => [[day, per_euro], ...] }, oldest first.
    def initialize(by_currency)
      @by_currency = by_currency
    end

    # An amount in another currency at a day's rate; nil where the ECB has no
    # rate for either.
    def convert(amount, from, to, day)
      return amount if from == to

      from_rate = per_euro(from, day)
      to_rate = per_euro(to, day)
      amount / from_rate * to_rate if from_rate && to_rate
    end

    private

    def per_euro(currency, day)
      return 1.0 if currency == EURO

      rates = @by_currency.fetch(currency, [])
      later = rates.bsearch_index { |rate_day, _| rate_day > day } || rates.size
      rates[later - 1].last if later.positive?
    end
  end
end
