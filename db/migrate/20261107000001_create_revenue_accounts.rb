class CreateRevenueAccounts < ActiveRecord::Migration[7.1]
  def change
    # A payment provider a builder connects, so their projects can show MRR:
    # one account per provider, read with a key that only reads, encrypted
    # at rest. Deleting the builder deletes it.
    create_table :revenue_accounts do |t|
      t.references :user, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false
      t.text :api_key, null: false
      t.timestamps
      t.index %i[user_id provider], unique: true
    end
  end
end
