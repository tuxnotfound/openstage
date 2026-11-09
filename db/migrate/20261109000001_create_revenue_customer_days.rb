class CreateRevenueCustomerDays < ActiveRecord::Migration[7.1]
  def change
    # The last day a read counted, in the builder's zone at that read. Worked
    # out from read_at instead, a read crossing midnight or a change of zone
    # names a day the read never wrote.
    add_column :revenue_accounts, :read_through, :date

    # How many customers paid for exactly these products on a day, none for a
    # day without any. A project counts a customer once, and a builder can move
    # a product to another project with no read, so the count is kept by the
    # products and not by the project. Totals only: no customer is kept.
    create_table :revenue_customer_days do |t|
      t.references :revenue_account, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.date :day, null: false
      t.bigint :product_ids, array: true, null: false
      t.integer :customers, null: false
      t.index %i[revenue_account_id day product_ids], unique: true
    end

    reversible do |direction|
      direction.up { execute "UPDATE revenue_accounts SET read_through = read_at::date" }
    end
  end
end
