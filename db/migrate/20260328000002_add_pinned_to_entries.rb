class AddPinnedToEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :entries, :pinned, :boolean, default: false, null: false
    add_index :entries, [ :user_id, :pinned ]
  end
end
