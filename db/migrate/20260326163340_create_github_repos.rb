class CreateGithubRepos < ActiveRecord::Migration[7.1]
  def change
    create_table :github_repos do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :github_repo_id, null: false
      t.string :name, null: false
      t.string :full_name, null: false
      t.text :description
      t.string :url
      t.boolean :included, null: false, default: true
      t.string :default_branch
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :github_repos, [ :user_id, :github_repo_id ], unique: true
  end
end
