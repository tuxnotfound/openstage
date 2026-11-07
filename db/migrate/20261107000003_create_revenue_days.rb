class CreateRevenueDays < ActiveRecord::Migration[7.1]
  def change
    # When Openstage last read the account's revenue: its newest day is that
    # day, in the builder's zone.
    add_column :revenue_accounts, :read_at, :datetime

    # A product's MRR and paying subscriptions on a day, in the builder's zone,
    # a row for each currency it was paid in, none for a day without revenue.
    # Daily totals only: no invoice, subscription or customer is kept. mrr is
    # in the currency's smallest unit, as Stripe counts it.
    create_table :revenue_days do |t|
      t.references :revenue_product, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.date :day, null: false
      t.string :currency, null: false
      t.bigint :mrr, null: false
      t.integer :subscriptions, null: false
      t.index %i[revenue_product_id day currency], unique: true
    end
  end
end
