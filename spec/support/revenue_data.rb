# A product's day as a read writes it: its MRR and paying subscriptions, each
# subscription its own customer's, buying this product alone.
module RevenueData
  def revenue_day(product, day:, currency: "usd", mrr: 0, subscriptions: 0)
    product.revenue_days.create!(day: day, currency: currency, mrr: mrr, subscriptions: subscriptions)
    return if subscriptions.zero?

    customers = product.revenue_account.revenue_customer_days.find_or_initialize_by(day: day, product_ids: [ product.id ])
    customers.update!(customers: customers.customers.to_i + subscriptions)
  end
end

RSpec.configure { |config| config.include RevenueData }
