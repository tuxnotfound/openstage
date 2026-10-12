# What the week card shows beyond commit counts: lines changed and languages
# per commit, a repo's stars, and a daily snapshot of them to tell stars gained.
class AddGithubExtras < ActiveRecord::Migration[7.1]
  def change
    change_table :entries, bulk: true do |t|
      t.integer :additions
      t.integer :deletions
      t.integer :files_changed
      t.jsonb :languages
      t.datetime :stats_fetched_at
    end

    add_column :github_repos, :stars_count, :integer

    create_table :github_repo_star_counts do |t|
      t.references :github_repo, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :recorded_on, null: false
      t.integer :stars, null: false
      t.timestamps
    end
    add_index :github_repo_star_counts, [ :github_repo_id, :recorded_on ], unique: true,
                                                                         name: "index_star_counts_on_repo_and_day"
  end
end
