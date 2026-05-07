class CreateFollows < ActiveRecord::Migration[7.1]
  def change
    create_table :follows do |t|
      t.bigint :follower_id, null: false
      t.bigint :followee_id, null: false
      t.timestamps
    end

    add_index :follows, [ :follower_id, :followee_id ], unique: true
    add_index :follows, :followee_id
    add_foreign_key :follows, :users, column: :follower_id
    add_foreign_key :follows, :users, column: :followee_id
  end
end
