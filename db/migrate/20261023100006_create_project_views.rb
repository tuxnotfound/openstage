# Visits to a project's page, kept apart from the builder's page so the
# numbers analytics shows today keep their meaning. Nothing shows them yet.
class CreateProjectViews < ActiveRecord::Migration[7.1]
  def change
    create_table :project_views do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :repo_name, null: false
      t.datetime :viewed_at, null: false
      t.string :referrer
      t.string :ip_hash
      t.string :country
      t.timestamps
    end
    add_index :project_views, [ :user_id, :repo_name, :viewed_at ]
  end
end
