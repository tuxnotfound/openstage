module Revenue
  # Each product's daily totals from the counted lines covering each day: its MRR,
  # the sum of their monthly amounts, and the subscriptions paying. Lines are
  # added one by one as they are read, and only the changes they make are
  # kept, so a long history stays small. Days run up to today; a day with no
  # MRR and nobody paying has no row.
  class Tally
    # A counted period of one subscription's product: from its first day to the
    # day after its last (to), monthly in the currency's smallest unit.
    Line = Data.define(:product_id, :currency, :subscription, :from, :to, :monthly)

    def initialize(today:)
      @today = today
      @amounts = Hash.new { |hash, key| hash[key] = Hash.new(0) }
      @spans = Hash.new { |hash, key| hash[key] = Hash.new { |by_subscription, id| by_subscription[id] = [] } }
    end

    def add(line)
      return unless line.from < line.to

      key = [ line.product_id, line.currency ]
      @amounts[key][line.from] += line.monthly
      @amounts[key][line.to] -= line.monthly
      @spans[key][line.subscription] << (line.from...line.to)
    end

    # Rows for RevenueDay: each product and currency, from its first counted day.
    def rows
      @amounts.flat_map { |key, changes| rows_for(key, changes, paying_changes(@spans[key])) }
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
