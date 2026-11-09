module Revenue
  # What MRR needs of a discount an invoice names, so the rest of Stripe's answer
  # is not kept while reading: how long its coupon lasts, nil once the coupon is
  # deleted, and whether it still sits on the customer, where no subscription
  # carries it. An invoice names a discount on one item only on its line, so
  # those never reach here.
  class StripeDiscount
    PLACES = %i[subscription subscription_item invoice invoice_item].freeze

    attr_reader :duration, :ends_at

    def initialize(stripe)
      coupon = stripe.dig(:source, :coupon)
      @duration = coupon[:duration] if coupon.is_a?(Hash)
      @ends_at = stripe[:end]
      @on_customer = PLACES.none? { |place| stripe[place] } && !stripe[:deleted] && @duration != "once"
    end

    def on_customer?
      @on_customer
    end
  end
end
