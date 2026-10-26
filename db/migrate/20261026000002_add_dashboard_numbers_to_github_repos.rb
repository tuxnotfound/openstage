class AddDashboardNumbersToGithubRepos < ActiveRecord::Migration[7.1]
  # The numbers a project draws on its builder's dashboard chart beside its
  # commits: "visits" now, "mrr" once revenue is counted.
  def change
    add_column :github_repos, :dashboard_numbers, :jsonb, default: [ "visits" ], null: false
  end
end
