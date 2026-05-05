class CreateEntryClicks < ActiveRecord::Migration[7.1]
  def change
    create_table :entry_clicks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :entry, null: false, foreign_key: true
      t.string :ip_hash
      t.datetime :clicked_at, null: false

      t.timestamps
    end

    add_index :entry_clicks, [ :user_id, :clicked_at ]
    add_index :entry_clicks, [ :entry_id, :clicked_at ]
  end
end
