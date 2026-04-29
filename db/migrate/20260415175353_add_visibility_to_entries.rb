class AddVisibilityToEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :entries, :visibility, :string, default: "public", null: false
  end
end
