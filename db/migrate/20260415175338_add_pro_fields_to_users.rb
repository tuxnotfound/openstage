class AddProFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :pro, :boolean, default: false, null: false
    add_column :users, :stripe_customer_id, :string
    add_column :users, :stripe_subscription_id, :string
    add_column :users, :pro_since, :datetime
  end
end
