# A year of MRR on two of the heavy builder's projects, from four Stripe
# products in two currencies, with the ECB's rates, so analytics' MRR tab can
# be measured. seed.rb loads it; on a database seeded before it, it runs alone:
#   DATABASE_URL=postgres:///openstage_perf bin/rails runner script/perf/revenue.rb
# The account reads as live for three days after (RevenueAccount::READ_LASTS):
# run it again to measure later.
abort "Refusing: run this on a scratch database whose name contains 'perf'." unless ActiveRecord::Base.connection.current_database.include?("perf")

heavy = User.find_by!(username: "heavy")
heavy.revenue_accounts.destroy_all
today = Time.current.in_time_zone(heavy.zone).to_date
days = (today - 364)..today
account = heavy.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_perf", read_at: Time.current, read_through: today)
first, second = GithubRepo.where(user: heavy).order(:id).first(2)
products = [ [ "Pro, monthly", first, "usd", 900 ], [ "Pro, yearly", first, "usd", 700 ], [ "Team", first, "eur", 2_900 ], [ "Solo", second, "usd", 1_900 ] ]

products.each_with_index do |(name, repo, currency, price), i|
  product = account.revenue_products.create!(external_id: "prod_perf_#{i}", name: "#{repo.name} #{name}", github_repo: repo)
  subscriptions = days.each_with_index.map { |_, n| 5 + (n * (i + 2) / 20) }
  RevenueDay.insert_all!(days.zip(subscriptions).map { |day, count| { revenue_product_id: product.id, day: day, currency: currency, mrr: count * price, subscriptions: count } })
  RevenueCustomerDay.insert_all!(days.zip(subscriptions).map { |day, count| { revenue_account_id: account.id, day: day, product_ids: [ product.id ], customers: count } })
end
ExchangeRate.where(currency: "usd", day: days).delete_all
ExchangeRate.insert_all!(days.reject { |day| day.saturday? || day.sunday? }.each_with_index.map { |day, n| { currency: "usd", day: day, per_euro: (1.1 + Math.sin(n / 40.0) / 50).round(4) } })
puts "revenue days #{RevenueDay.count}, rates #{ExchangeRate.count}"
