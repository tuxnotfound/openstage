# A project its builder pins wears a colour on their stage, with a card and a
# line; once they pin any, only pinned ones do (Progress::Projects).
class AddPinnedToGithubRepos < ActiveRecord::Migration[7.1]
  def change
    add_column :github_repos, :pinned, :boolean, default: false, null: false
  end
end
