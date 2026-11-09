module Revenue
  # Reads a builder's Stripe account again from its first sale: its products,
  # then every invoice, into each product's daily MRR and paying subscriptions
  # (MrrLines, Tally), in place of what the last read wrote. Reading it
  # all every night keeps no invoice, and mends any night the read missed. A
  # key Stripe refuses is no failure of ours: it is recorded, which takes the
  # account's figures off the pages (Book#live?), and the next read that works
  # brings them back.
  class ReadService < ApplicationService
    include Paging

    attr_accessor :account

    validates :account, presence: true

    private

    def execute
      import = ImportProductsService.new(account: account)
      import.call
      return unless absorb_errors(import)

      tally = Tally.new(today: Time.current.in_time_zone(zone).to_date)
      each_counted_line { |line| tally.add(line) }
      rows = tally.rows
      save(rows + unsold_rows(rows))
    rescue ApplicationGateway::Unauthorized
      account.update!(refused_at: Time.current)
    end

    def each_counted_line(&block)
      lines = MrrLines.new(products: account.revenue_products.pluck(:external_id, :id).to_h, recurring: recurring_prices,
                           subscriptions: subscriptions, zone: zone)
      each_item(->(params) { StripeGateway.invoices(key, **params) }) do |invoice|
        lines_of(invoice).each { |line| lines.read(line, invoice[:status], &block) }
      end
      lines.read_held(&block)
    end

    def recurring_prices
      prices.to_h { |price| [ price[:id], price[:recurring] ] }
    end

    # Only what MRR needs of each price and subscription is kept while reading.
    def prices
      @prices ||= all_items(->(params) { StripeGateway.prices(key, **params) }).map { |price| price.slice(:id, :product, :currency, :recurring) }
    end

    def subscriptions
      subscriptions = {}
      each_item(->(params) { StripeGateway.subscriptions(key, status: "all", **params) }) { |subscription| subscriptions[subscription[:id]] = StripeSubscription.new(subscription) }
      subscriptions
    end

    # An invoice carries its first lines; one with more is read for the rest.
    def lines_of(invoice)
      return invoice.dig(:lines, :data) || [] unless invoice.dig(:lines, :has_more)

      all_items(->(params) { StripeGateway.invoice_lines(key, invoice[:id], **params) })
    end

    # MRR shows before any sale too: a product with no days stands at nothing
    # from the day Stripe was connected, in its newest price's currency. With no
    # price there is no currency to write it in.
    def unsold_rows(rows)
      connected = account.created_at.in_time_zone(zone).to_date
      account.revenue_products.where.not(id: rows.map { |row| row[:revenue_product_id] }).filter_map do |product|
        currency = prices.find { |price| price[:product] == product.external_id }&.dig(:currency)
        { revenue_product_id: product.id, day: connected, currency: currency, mrr: 0, subscriptions: 0 } if currency
      end
    end

    def save(rows)
      transaction do
        RevenueDay.where(revenue_product_id: account.revenue_products.select(:id)).delete_all
        rows.each_slice(1000) { |slice| RevenueDay.insert_all(slice) }
        account.update!(read_at: Time.current, refused_at: nil)
      end
    end

    def key
      account.api_key
    end

    def zone
      account.user.zone
    end
  end
end
