# A visitor leaves an email on a builder's page. The builder owns the list.
# Nothing here is ever shown as a count on the public page.
class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :email, null: false
      t.string :token, null: false
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.timestamps
    end

    add_index :subscriptions, [ :user_id, :email ], unique: true
    add_index :subscriptions, :token, unique: true
  end
end
