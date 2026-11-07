module Revenue
  # An amount as Stripe counts it, in the currency's smallest unit, written in
  # whole units for the pages: "$4,210", "€420", "¥52,000", "1,200 SEK".
  module Money
    # The currencies Stripe counts without a smaller unit (Stripe's docs).
    ZERO_DECIMAL = %w[bif clp djf gnf jpy kmf krw mga pyg rwf ugx vnd vuv xaf xof xpf].freeze
    SYMBOLS = { "usd" => "$", "eur" => "€", "gbp" => "£", "jpy" => "¥", "inr" => "₹", "cad" => "CA$", "aud" => "A$", "brl" => "R$" }.freeze

    def self.format(amount, currency)
      units = ZERO_DECIMAL.include?(currency) ? amount : (amount / 100.0).round
      number = ActiveSupport::NumberHelper.number_to_delimited(units)
      symbol = SYMBOLS[currency]
      symbol ? "#{symbol}#{number}" : "#{number} #{currency.upcase}"
    end
  end
end
