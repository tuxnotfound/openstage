module Revenue
  # What MRR needs of a Stripe subscription, so the rest of Stripe's answer is
  # not kept while reading. Stripe counts one while payment is being collected:
  # active or past due, and a cancelled one up to the moment of cancelling, even
  # if it runs on to its period's end. Unpaid, or with collection paused, only
  # what was paid counts. It says what it charges now, with its current items.
  class StripeSubscription
    COLLECTED = %w[active past_due canceled].freeze
    Item = Data.define(:id, :product, :price, :recurring, :currency, :unit_amount, :quantity, :created)

    attr_reader :customer, :stopped_at, :discounts, :currency, :items

    def initialize(stripe)
      @customer = stripe[:customer]
      @status = stripe[:status]
      @stopped_at = stripe[:canceled_at] || stripe[:ended_at]
      @collected = COLLECTED.include?(@status) && stripe[:pause_collection].nil?
      @currency = stripe[:currency]
      listed = Array(stripe.dig(:items, :data))
      @discounts = Array(stripe[:discounts]) + listed.flat_map { |item| Array(item[:discounts]) }
      @whole = !stripe.dig(:items, :has_more)
      @items = listed.map { |item| item_of(item) }
    end

    def collected?
      @collected
    end

    # Whether what it charges now is its MRR today. Not with items left off
    # Stripe's answer, where its invoices say more.
    def counting?
      collected? && @status != "canceled" && stopped_at.nil? && @whole && items.any?
    end

    def item(id)
      items.find { |each| each.id == id }
    end

    private

    def item_of(item)
      price = item[:price] || {}
      Item.new(id: item[:id], product: price[:product], price: price[:id], recurring: price[:recurring], currency: price[:currency],
               unit_amount: price[:unit_amount], quantity: item[:quantity], created: item[:created])
    end
  end
end
