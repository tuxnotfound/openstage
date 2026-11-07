module Revenue
  # Reads every product in a builder's Stripe account, archived ones too, since
  # their subscriptions can still pay. A product's name follows Stripe's, and
  # the project it counts for stays. A product gone from Stripe goes here too.
  class ImportProductsService < ApplicationService
    include Paging

    attr_accessor :account

    validates :account, presence: true

    private

    def execute
      products = all_items(->(params) { StripeGateway.products(account.api_key, **params) })
      transaction do
        keep(products)
        account.revenue_products.where.not(external_id: products.pluck(:id)).delete_all
        account.update!(products_read_at: Time.current)
      end
    end

    def keep(products)
      return if products.empty?

      now = Time.current
      RevenueProduct.upsert_all(
        products.map { |product| { revenue_account_id: account.id, external_id: product[:id], name: product[:name], active: product[:active], created_at: now, updated_at: now } },
        unique_by: %i[revenue_account_id external_id], update_only: %i[name active]
      )
    end
  end
end
