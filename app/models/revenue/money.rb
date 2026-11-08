module Revenue
  # An amount as Stripe counts it, in the currency's smallest unit, written in
  # whole units for the pages: "$4,210", "€420", "¥52,000", "1,200 SEK".
  module Money
    # The currencies Stripe counts without a smaller unit (Stripe's docs).
    ZERO_DECIMAL = %w[bif clp djf gnf jpy kmf krw mga pyg rwf ugx vnd vuv xaf xof xpf].freeze
    THREE_DECIMAL = %w[bhd jod kwd omr tnd].freeze
    SYMBOLS = { "usd" => "$", "eur" => "€", "gbp" => "£", "jpy" => "¥", "inr" => "₹", "cad" => "CA$", "aud" => "A$", "brl" => "R$" }.freeze

    def self.format(amount, currency)
      write(units(amount, currency), currency)
    end

    # An amount as Stripe counts it, in the currency's units: 12.5 for 1250 cents.
    def self.units(amount, currency)
      amount / divisor(currency).to_f
    end

    # Units of a currency as the pages write them, whole.
    def self.write(units, currency)
      number = ActiveSupport::NumberHelper.number_to_delimited(units.round)
      symbol = SYMBOLS[currency]
      symbol ? "#{symbol}#{number}" : "#{number} #{currency.upcase}"
    end

    def self.divisor(currency)
      return 1 if ZERO_DECIMAL.include?(currency)

      THREE_DECIMAL.include?(currency) ? 1000 : 100
    end
    private_class_method :divisor
  end
end
