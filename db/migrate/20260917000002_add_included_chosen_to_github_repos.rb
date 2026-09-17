class AddIncludedChosenToGithubRepos < ActiveRecord::Migration[7.1]
  def change
    # True once the user has set Included/Excluded by hand. The sync's one-time
    # private re-default must never override a choice.
    add_column :github_repos, :included_chosen, :boolean, default: false, null: false
  end
end
