# The Openstage GitHub App installation that reads a builder's private repos (C12).
class AddGithubInstallationIdToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :github_installation_id, :bigint
  end
end
