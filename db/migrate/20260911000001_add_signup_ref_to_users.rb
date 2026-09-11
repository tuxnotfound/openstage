class AddSignupRefToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :signup_ref, :string
    add_index :users, :signup_ref
  end
end
