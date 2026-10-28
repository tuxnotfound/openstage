class AddSiteSetUpAtToGithubRepos < ActiveRecord::Migration[7.1]
  # When a project's site visits were first set up with Openstage's script,
  # kept for good: Free counts the project set up first. A project with a
  # site token has been set up; it takes its first visit's time, else its
  # last update's.
  def up
    add_column :github_repos, :site_set_up_at, :datetime
    execute "UPDATE github_repos SET site_set_up_at = COALESCE(site_first_visit_at, updated_at) WHERE site_token IS NOT NULL"
  end

  def down
    remove_column :github_repos, :site_set_up_at
  end
end
