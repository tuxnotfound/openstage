class AddDashboardHiddenToGithubRepos < ActiveRecord::Migration[7.1]
  # The numbers a builder switched off for a project on their dashboard's
  # chart; every other number it has draws, so a new one starts on.
  def change
    add_column :github_repos, :dashboard_hidden, :jsonb, default: [], null: false
  end
end
