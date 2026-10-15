# Commits on branches other than the default (FUTURE_FEATURES item 7). An entry's
# branch names the branch a commit is only on, until it reaches the default
# branch. The builder's switch shows or hides them, on by default. A repo keeps
# each branch's last head it read, so the sync reads only branches that moved.
class AddBranchCommits < ActiveRecord::Migration[7.1]
  def change
    add_column :entries, :branch, :string
    add_column :users, :branch_commits, :boolean, default: true, null: false
    add_column :github_repos, :branch_heads, :jsonb, default: {}, null: false
  end
end
