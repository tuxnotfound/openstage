# A reader may follow one project instead of the builder's whole page. The
# address stays unique per page followed: once for the builder, once per
# project.
class AddProjectToSubscriptions < ActiveRecord::Migration[7.1]
  def change
    add_reference :subscriptions, :github_repo, foreign_key: { on_delete: :cascade }, index: false
    remove_index :subscriptions, [ :user_id, :email ], unique: true
    add_index :subscriptions, [ :user_id, :email ], unique: true, where: "github_repo_id IS NULL"
    add_index :subscriptions, [ :github_repo_id, :email ], unique: true, where: "github_repo_id IS NOT NULL"
  end
end
