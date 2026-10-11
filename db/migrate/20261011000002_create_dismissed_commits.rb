# Commits a builder deleted from their page. A re-sync from scratch (a renamed
# default branch, a private repo picked again) would otherwise import them again.
class CreateDismissedCommits < ActiveRecord::Migration[7.1]
  def change
    create_table :dismissed_commits do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :sha, null: false
      t.timestamps
    end
    add_index :dismissed_commits, [ :user_id, :sha ], unique: true
  end
end
