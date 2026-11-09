module Revenue
  # Each product's daily totals from the lines covering each day (MrrLines): its MRR,
  # the sum of their monthly amounts, and the subscriptions paying; and how many
  # customers paid for which products. Lines are added one by one as they are
  # read, and only the changes they make are kept, so a long history stays small.
  # Days run up to today; a day with no MRR and nobody paying has no row.
  class Tally
    # A counted period of one subscription's product: from its first day to the
    # day after its last (to), monthly in the currency's smallest unit.
    Line = Data.define(:product_id, :currency, :subscription, :customer, :from, :to, :monthly)

    def initialize(today:)
      @today = today
      @amounts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @spans = Hash.new { |hash, key| hash[key] = Hash.new { |by_subscription, id| by_subscription[id] = [] } }
      @customers = Hash.new { |hash, customer| hash[customer] = Hash.new { |by_product, id| by_product[id] = [] } }
    end

    def add(line)
      return unless line.from < line.to

      key = [ line.product_id, line.currency ]
      @amounts[key][line.from] += line.monthly
      @amounts[key][line.to] -= line.monthly
      @spans[key][line.subscription] << (line.from...line.to)
      @customers[line.customer][line.product_id] << (line.from...line.to)
    end

    # Rows for RevenueDay: each product and currency, from its first counted day.
    def rows
      @amounts.flat_map { |key, changes| rows_for(key, changes, paying_changes(@spans[key])) }
    end

    # Rows for RevenueCustomerDay: how many customers paid for exactly which
    # products each day. Which project a product counts for can change with no
    # read, so these count a customer once for any project.
    def customer_rows
      changes = Hash.new { |hash, product_ids| hash[product_ids] = Hash.new(0) }
      @customers.each_value do |by_product|
        each_spell(by_product) do |product_ids, from, to|
          changes[product_ids][from] += 1
          changes[product_ids][to] -= 1
        end
      end
      changes.flat_map { |product_ids, at| customer_rows_for(product_ids, at) }
    end

    private

    def rows_for((product_id, currency), changes, paying)
      mrr = 0
      subscriptions = 0
      (changes.keys.min..@today).filter_map do |day|
        mrr += changes.fetch(day, 0)
        subscriptions += paying.fetch(day, 0)
        { revenue_product_id: product_id, day: day, currency: currency, mrr: mrr.round, subscriptions: subscriptions } if mrr.round.positive? || subscriptions.positive?
      end
    end

    # A subscription pays once on a day, however many of its lines cover it.
    def paying_changes(by_subscription)
      by_subscription.each_value.with_object(Hash.new(0)) do |spans, changes|
        merged(spans).each do |span|
          changes[span.begin] += 1
          changes[span.end] -= 1
        end
      end
    end

    # Yields each stretch of days a customer paid for one same set of products.
    def each_spell(by_product)
      spans = by_product.transform_values { |each| merged(each) }
      spans.values.flatten.flat_map { |span| [ span.begin, span.end ] }.uniq.sort.each_cons(2) do |from, to|
        product_ids = spans.select { |_, each| each.any? { |span| span.cover?(from) } }.keys.sort
        yield product_ids, from, to if product_ids.any?
      end
    end

    def customer_rows_for(product_ids, changes)
      customers = 0
      (changes.keys.min..@today).filter_map do |day|
        customers += changes.fetch(day, 0)
        { day: day, product_ids: product_ids, customers: customers } if customers.positive?
      end
    end

    def merged(spans)
      spans.sort_by(&:begin).each_with_object([]) do |span, out|
        if out.any? && span.begin <= out.last.end
          out[-1] = (out.last.begin...[ out.last.end, span.end ].max)
        else
          out << span
        end
      end
    end
  end
end
