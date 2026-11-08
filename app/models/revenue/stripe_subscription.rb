module Revenue
  # What MRR needs of a Stripe subscription, so the rest of Stripe's answer is
  # not kept while reading. Stripe counts one while payment is being collected:
  # active or past due, and a cancelled one up to the moment of cancelling, even
  # if it runs on to its period's end. Unpaid, or with collection paused, only
  # what was paid counts.
  class StripeSubscription
    COLLECTED = %w[active past_due canceled].freeze

    attr_reader :stopped_at, :discounts

    def initialize(stripe)
      @stopped_at = stripe[:canceled_at] || stripe[:ended_at]
      @collected = COLLECTED.include?(stripe[:status]) && stripe[:pause_collection].nil?
      @discounts = Array(stripe[:discounts]) + Array(stripe.dig(:items, :data)).flat_map { |item| Array(item[:discounts]) }
    end

    def collected?
      @collected
    end
  end
end
