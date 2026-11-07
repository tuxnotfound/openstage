class CreateRevenueProducts < ActiveRecord::Migration[7.1]
  def change
    # When Openstage last read the account's products, so a project's view can
    # say they are still on their way.
    add_column :revenue_accounts, :products_read_at, :datetime

    # A product in a builder's payment account, and the one project it counts
    # for, if any. Removing the project leaves the product uncounted.
    create_table :revenue_products do |t|
      t.references :revenue_account, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :github_repo, foreign_key: { on_delete: :nullify }
      t.string :external_id, null: false
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
      t.index %i[revenue_account_id external_id], unique: true
    end

    # The first time a project was given a product, kept for good: Free shows
    # MRR, to its builder alone, for the one set up first (Revenue::Slot).
    add_column :github_repos, :revenue_set_up_at, :datetime
  end
end
