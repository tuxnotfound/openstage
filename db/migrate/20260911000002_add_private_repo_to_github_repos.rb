class AddPrivateRepoToGithubRepos < ActiveRecord::Migration[7.1]
  def change
    # Named private_repo rather than private to avoid colliding with Ruby's
    # visibility keyword on the model.
    add_column :github_repos, :private_repo, :boolean, default: false, null: false
  end
end
