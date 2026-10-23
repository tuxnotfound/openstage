# Clicks on a project page's Visit and View on GitHub buttons, by the repo's
# full name. Counted for later; nothing shows them yet.
class CreateProjectClicks < ActiveRecord::Migration[7.1]
  def change
    create_table :project_clicks do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :repo_name, null: false
      t.string :kind, null: false
      t.string :ip_hash
      t.datetime :clicked_at, null: false
      t.timestamps
    end
    add_index :project_clicks, [ :user_id, :repo_name, :clicked_at ]
  end
end
