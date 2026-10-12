# What a builder did on GitHub beyond commits and releases, for the week card:
# pull requests they merged and deploys of their repos. Kept apart from
# entries, since the card counts these and the page never lists them.
class CreateGithubActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :github_activities do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :github_repo, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :kind, null: false
      t.bigint :external_id, null: false
      t.datetime :occurred_at, null: false
      t.string :title
      t.string :environment
      t.timestamps
    end
    add_index :github_activities, [ :github_repo_id, :kind, :external_id ], unique: true, name: "index_github_activities_once"
    add_index :github_activities, [ :user_id, :kind, :occurred_at ], name: "index_github_activities_on_user_kind_time"
  end
end
