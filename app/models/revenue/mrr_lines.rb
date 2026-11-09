module Revenue
  # A Stripe account's MRR as lines for the Tally, by Stripe's rules: per
  # month, without tax, a yearly plan a twelfth of its price, a weekly one 52
  # twelfths. A usage-based price adds nothing, though its customer is paying.
  # A refund changes nothing. Today is what each subscription charges now, as
  # Stripe counts it, since a plan change does not always make an invoice. The
  # days before are its invoices' periods, never a proration or a one-off item,
  # one at a time for each subscription item, and what it charges now fills any
  # days they leave. A period ends early when its subscription was cancelled
  # first. Days are in the builder's zone.
  class MrrLines
    PER_MONTH = { "day" => Rational(365, 12), "week" => Rational(52, 12), "month" => 1, "year" => Rational(1, 12) }.freeze

    # One invoice line, as little of it as MRR needs while reading. discounts:
    # {discount id => its amount}. tax: what its amount holds of a price that
    # includes tax, taxed on what was charged after every discount.
    Period = Data.define(:item, :subscription, :product_id, :currency, :from, :to, :recurring, :amount, :discounts, :tax) do
      def tax_share
        charged = amount - discounts.values.sum
        tax.positive? && charged.positive? ? Rational(tax, charged) : 0
      end
    end

    # products: {Stripe product id => RevenueProduct id}; recurring: {Stripe
    # price id => its recurring hash, nil for a one-off price}; subscriptions:
    # {Stripe subscription id => StripeSubscription}.
    def initialize(products:, recurring:, subscriptions:, zone:, today:)
      @products = products
      @recurring = recurring
      @subscriptions = subscriptions
      @zone = zone
      @today = today
      @periods = Hash.new { |periods, item| periods[item] = [] }
      @discount_periods = Hash.new { |periods, key| periods[key] = Set.new }
      @discounts = {}
    end

    # Takes the discounts an invoice names, each with its coupon.
    def read_discounts(discounts)
      Array(discounts).each { |discount| @discounts[discount[:id]] = StripeDiscount.new(discount) }
    end

    # Takes one of Stripe's invoice lines, unless MRR leaves it out.
    def read(line, invoice_status)
      return unless counted?(line, invoice_status)

      period = period_of(line)
      return unless period

      period.discounts.each_key { |discount| @discount_periods[[ discount, period.item ]] << period.from }
      @periods[period.item] << period
    end

    # Yields every Tally::Line, once all the invoices are read: only then is it
    # known which discounts last and where each period ends.
    def each_line(&block)
      @periods.each_value { |periods| periods.sort_by!(&:from) }
      @periods.each_value { |periods| past_lines(periods, &block) }
      @subscriptions.each do |id, subscription|
        subscription.items.each { |item| now_line(id, subscription, item, &block) } if subscription.counting?
      end
    end

    private

    # What was paid, and an open invoice while Stripe collects it. A draft asks
    # nobody for anything yet, as those of an unpaid subscription, and an
    # uncollectible one was given up on, as those of a pause: neither comes back
    # when its subscription is later cancelled or resumed.
    def counted?(line, invoice_status)
      details = line.dig(:parent, :subscription_item_details)
      return false if details.nil? || details[:proration]

      invoice_status == "paid" || (invoice_status == "open" && @subscriptions[details[:subscription]]&.collected?)
    end

    # nil at a one-off price.
    def period_of(line)
      details = line.dig(:parent, :subscription_item_details)
      price = line.dig(:pricing, :price_details, :price)
      recurring = @recurring[price] if price
      return unless recurring

      Period.new(item: details[:subscription_item] || "#{details[:subscription]}:#{price}", subscription: details[:subscription],
                 product_id: @products[line.dig(:pricing, :price_details, :product)], currency: line[:currency],
                 from: day(line.dig(:period, :start)), to: day(line.dig(:period, :end)), recurring: recurring, amount: line[:amount],
                 discounts: Array(line[:discount_amounts]).to_h { |discount| [ discount[:discount], discount[:amount] ] },
                 tax: Array(line[:taxes]).sum { |tax| tax[:tax_behavior] == "inclusive" ? tax[:amount] : 0 })
    end

    # Lines of one start are one period, as a price's tiers bill.
    def past_lines(periods)
      periods.each do |period|
        monthly = monthly_of(period)
        next unless monthly && period.product_id

        following = periods.find { |each| each.from > period.from }
        yield Tally::Line.new(product_id: period.product_id, currency: period.currency, subscription: period.subscription, customer: customer_of(period.subscription),
                              from: period.from, to: [ period.to, following&.from, stop_of(period) ].compact.min, monthly: monthly)
      end
    end

    # A subscription Stripe does not list stands for its own customer.
    def customer_of(subscription_id)
      @subscriptions[subscription_id]&.customer || subscription_id
    end

    # nil for a period that charges nothing.
    def monthly_of(period)
      kept = period.amount - period.discounts.sum { |discount, amount| lasting?(discount, period) ? amount : 0 }
      amount = kept * (1 - period.tax_share)
      return unless amount.positive?

      metered?(period.recurring) ? 0 : per_month(period.recurring, amount)
    end

    # Stripe leaves a one-off discount out of MRR and subtracts one that lasts,
    # as its coupon says. With no coupon to read, on one item or deleted, a
    # discount lasts if its subscription still carries it, or if it covered more
    # than one of an item's periods.
    def lasting?(discount, period)
      duration = @discounts[discount]&.duration
      return duration != "once" if duration

      @discount_periods[[ discount, period.item ]].size > 1 || carried?(discount, @subscriptions[period.subscription])
    end

    def carried?(discount, subscription)
      subscription&.discounts&.include?(discount)
    end

    def metered?(recurring)
      recurring[:usage_type] == "metered"
    end

    def per_month(recurring, amount)
      PER_MONTH.fetch(recurring[:interval]) * amount.to_r / recurring[:interval_count]
    end

    def stop_of(period)
      subscription = @subscriptions[period.subscription]
      return unless subscription

      stopped = day(subscription.stopped_at) if subscription.stopped_at
      [ stopped, (now_begins(subscription, period) if subscription.counting?) ].compact.min
    end

    # Where what a subscription charges now takes over from this period. An
    # item since replaced ends where a later item began, or else at today.
    def now_begins(subscription, period)
      item = subscription.item(period.item)
      return start_of(item) if item

      subscription.items.map { |each| added_on(each) }.select { |added| added > period.from }.min || @today
    end

    # Today, or the first day its invoices leave uncovered.
    def start_of(item)
      covered = @periods.fetch(item.id, []).map(&:to).max
      [ @today, covered || added_on(item) ].min
    end

    def added_on(item)
      item.created ? day(item.created) : @today
    end

    def now_line(id, subscription, item)
      product_id = @products[item.product]
      monthly = monthly_now(subscription, item)
      return unless product_id && monthly

      yield Tally::Line.new(product_id: product_id, currency: subscription.currency || item.currency, subscription: id, customer: customer_of(id),
                            from: start_of(item), to: @today + 1, monthly: monthly)
    end

    # At its price and quantity, less the discounts and tax of its last invoice
    # where its subscription still carries them. A price with no one amount,
    # as tiers, or in another currency: what its last invoice charged.
    def monthly_now(subscription, item)
      return unless item.recurring
      return 0 if metered?(item.recurring)

      last = @periods.fetch(item.id, []).then { |periods| periods.select { |period| period.from == periods.last.from } }
      return last.sum { |period| monthly_of(period) || 0 }.then { |sum| sum if sum.positive? } unless priced?(subscription, item)

      amount = charged_now(item.unit_amount * item.quantity.to_i, subscription, last.first)
      per_month(item.recurring, amount) if amount.positive?
    end

    def priced?(subscription, item)
      item.unit_amount && (subscription.currency.nil? || subscription.currency == item.currency)
    end

    def charged_now(full, subscription, last)
      return full unless last&.amount&.positive?

      running = last.discounts.sum { |discount, amount| running?(discount, subscription) ? amount : 0 }
      full * Rational(last.amount - running, last.amount) * (1 - last.tax_share)
    end

    # Whether a discount on its last invoice still comes off today. No
    # subscription carries one on the customer, so its coupon has to say.
    def running?(discount, subscription)
      return true if carried?(discount, subscription)

      found = @discounts[discount]
      found&.on_customer? && (found.ends_at.nil? || day(found.ends_at) > @today)
    end

    def day(timestamp)
      Time.at(timestamp).in_time_zone(@zone).to_date
    end
  end
end
