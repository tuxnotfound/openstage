class CreateProfileViews < ActiveRecord::Migration[7.1]
  def change
    create_table :profile_views do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :viewed_at, null: false
      t.string :referrer
      t.string :ip_hash

      t.timestamps
    end

    add_index :profile_views, [:user_id, :viewed_at]
  end
end
