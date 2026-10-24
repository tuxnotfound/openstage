# The builder's X account, and whether their page shows it and their email.
# Both stay hidden until the builder turns them on.
class AddContactsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :x_username, :string
    add_column :users, :show_email, :boolean, default: false, null: false
    add_column :users, :show_x_username, :boolean, default: false, null: false
  end
end
