class CreateSyncLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :sync_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source, null: false
      t.string :status, null: false
      t.integer :entries_added, null: false, default: 0
      t.text :error_message
      t.datetime :ran_at, null: false

      t.timestamps
    end
  end
end
