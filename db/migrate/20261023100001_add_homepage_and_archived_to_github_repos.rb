# A project's status reads from GitHub (PROJECTS_PLAN, decided 2026-10-21):
# "Live" when the repo has a website, "Archived" from its flag. GitHub sends
# both in every repo listing; they were dropped until now.
class AddHomepageAndArchivedToGithubRepos < ActiveRecord::Migration[7.1]
  def change
    add_column :github_repos, :homepage, :string
    add_column :github_repos, :archived, :boolean, default: false, null: false
  end
end
