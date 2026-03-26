class CreateEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :entry_type, null: false
      t.string :source, null: false
      t.string :title, null: false
      t.text :body
      t.string :url
      t.datetime :occurred_at, null: false
      t.boolean :hidden, null: false, default: false
      t.string :external_id
      t.string :repo_name

      t.timestamps
    end

    # DB-level dedup: one entry per user per external source ID.
    # NULL external_ids (manual entries) are always allowed — PG treats NULLs as distinct.
    add_index :entries, [ :user_id, :external_id ], unique: true
    add_index :entries, [ :user_id, :occurred_at ]
  end
end
