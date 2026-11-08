module Revenue
  # The lines of Stripe invoices as MRR counts them (Tally::Line), by Stripe's
  # rules: a subscription's period, never a proration or a one-off item, at a
  # recurring price, per month, without tax. A yearly plan counts a twelfth of
  # its price, a weekly one 52 twelfths. A usage-based price adds nothing, though
  # its customer is paying. A refund changes nothing. A period ends early when
  # its subscription was cancelled first. Days are in the builder's zone.
  class MrrLines
    PER_MONTH = { "day" => Rational(365, 12), "week" => Rational(52, 12), "month" => 1, "year" => Rational(1, 12) }.freeze

    # products: {Stripe product id => RevenueProduct id}; recurring: {Stripe
    # price id => its recurring hash, nil for a one-off price}; subscriptions:
    # {Stripe subscription id => StripeSubscription}.
    def initialize(products:, recurring:, subscriptions:, zone:)
      @products = products
      @recurring = recurring
      @subscriptions = subscriptions
      @zone = zone
      @discount_periods = Hash.new { |periods, id| periods[id] = Set.new }
      @held = []
    end

    # Yields the Tally::Line of one of Stripe's invoice lines, unless MRR leaves
    # it out. A discounted line waits for read_held.
    def read(line, invoice_status, &block)
      return unless counted?(line, invoice_status)
      return give(line, &block) if line[:discount_amounts].blank?

      hold(line)
    end

    # The discounted lines, once every invoice is read: only then is it known
    # which discounts last.
    def read_held(&block)
      @held.each { |line| give(line, &block) }
    end

    private

    def counted?(line, invoice_status)
      details = line.dig(:parent, :subscription_item_details)
      return false if details.nil? || details[:proration] || invoice_status == "void"

      invoice_status == "paid" || subscription_of(line)&.collected?
    end

    def subscription_of(line)
      @subscriptions[line.dig(:parent, :subscription_item_details, :subscription)]
    end

    def give(line)
      product_id = @products[line.dig(:pricing, :price_details, :product)]
      monthly = per_month(line)
      return unless product_id && monthly

      yield Tally::Line.new(product_id: product_id, currency: line[:currency], subscription: line.dig(:parent, :subscription_item_details, :subscription),
                            from: day(line.dig(:period, :start)), to: day([ line.dig(:period, :end), subscription_of(line)&.stopped_at ].compact.min),
                            monthly: monthly)
    end

    def hold(line)
      line[:discount_amounts].each { |discount| @discount_periods[discount[:discount]] << line.dig(:period, :start) }
      @held << line
    end

    # nil for a line that charges nothing, or at a one-off price.
    def per_month(line)
      recurring = @recurring[line.dig(:pricing, :price_details, :price)]
      amount = net(line)
      return unless recurring && amount.positive?
      return 0 if recurring[:usage_type] == "metered"

      PER_MONTH.fetch(recurring[:interval]) * amount / recurring[:interval_count]
    end

    # A period's amount after the discounts that last, without tax. A price
    # that includes tax holds it in its amount, taxed on what was charged after
    # every discount, so its share is what comes off.
    def net(line)
      discounts = Array(line[:discount_amounts])
      kept = line[:amount] - discounts.sum { |discount| lasting?(discount[:discount], line) ? discount[:amount] : 0 }
      charged = line[:amount] - discounts.sum { |discount| discount[:amount] }
      tax = Array(line[:taxes]).sum { |one| one[:tax_behavior] == "inclusive" ? one[:amount] : 0 }
      tax.positive? && charged.positive? ? kept * Rational(charged - tax, charged) : kept
    end

    # Stripe leaves a one-off discount out of MRR and subtracts one that lasts.
    # A restricted key cannot read coupons, and asking it to would refuse every
    # key already connected, so a discount lasts if its subscription still
    # carries it, or if it covered more than one period.
    def lasting?(discount, line)
      @discount_periods[discount].size > 1 || subscription_of(line)&.discounts&.include?(discount)
    end

    def day(timestamp)
      Time.at(timestamp).in_time_zone(@zone).to_date
    end
  end
end
