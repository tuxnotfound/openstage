class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :github_uid
      t.string :github_username
      t.string :github_access_token
      t.string :username
      t.string :display_name
      t.text :bio
      t.string :avatar_url
      t.string :website_url
      t.date :building_since
      t.datetime :username_changed_at

      t.timestamps
    end
    add_index :users, :github_uid, unique: true
    add_index :users, :username, unique: true
  end
end
