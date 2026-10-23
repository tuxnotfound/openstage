# The builder's own words, website and picture for a project. GitHub's come
# first; once the builder writes their own, theirs win (PROJECTS_PLAN, before
# the revamp is complete).
class AddBuilderEditsToGithubRepos < ActiveRecord::Migration[7.1]
  def change
    add_column :github_repos, :description_edit, :text
    add_column :github_repos, :website_edit, :string
    add_column :github_repos, :image_edit, :string
  end
end
