module Revenue
  # The lines of paid Stripe invoices as MRR counts them (Tally::Line): a
  # subscription's period, never a proration or a one-off item, at a
  # recurring price, its amount after discounts, per month. A yearly plan
  # counts a twelfth of its price, a weekly one 52 twelfths. A period ends
  # early when its subscription ended first. Days are in the builder's zone.
  class PaidLines
    PER_MONTH = { "day" => Rational(365, 12), "week" => Rational(52, 12), "month" => 1, "year" => Rational(1, 12) }.freeze

    # products: {Stripe product id => RevenueProduct id}; recurring: {Stripe
    # price id => its recurring hash, nil for a one-off price}; endings:
    # {Stripe subscription id => when it ended, nil while it runs}.
    def initialize(products:, recurring:, endings:, zone:)
      @products = products
      @recurring = recurring
      @endings = endings
      @zone = zone
    end

    # The Tally::Line for one of Stripe's invoice lines, nil for any MRR leaves out.
    def tally_line(line)
      details = line.dig(:parent, :subscription_item_details)
      return if details.nil? || details[:proration]

      product_id = @products[line.dig(:pricing, :price_details, :product)]
      monthly = per_month(line)
      return unless product_id && monthly&.positive?

      Tally::Line.new(product_id: product_id, currency: line[:currency], subscription: details[:subscription],
                      from: day(line.dig(:period, :start)), to: day([ line.dig(:period, :end), @endings[details[:subscription]] ].compact.min),
                      monthly: monthly)
    end

    private

    def per_month(line)
      recurring = @recurring[line.dig(:pricing, :price_details, :price)]
      return unless recurring

      net = line[:amount] - Array(line[:discount_amounts]).sum { |discount| discount[:amount] }
      PER_MONTH.fetch(recurring[:interval]) * net / recurring[:interval_count]
    end

    def day(timestamp)
      Time.at(timestamp).in_time_zone(@zone).to_date
    end
  end
end
