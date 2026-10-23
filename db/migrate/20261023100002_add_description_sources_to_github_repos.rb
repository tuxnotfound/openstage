# Where a project's page finds its words and picture when the repo's GitHub
# description is empty: the README's first line, and the custom social preview
# image its owner set. Read at most once a day (described_at).
class AddDescriptionSourcesToGithubRepos < ActiveRecord::Migration[7.1]
  def change
    add_column :github_repos, :readme_line, :string
    add_column :github_repos, :preview_image_url, :string
    add_column :github_repos, :described_at, :datetime
  end
end
