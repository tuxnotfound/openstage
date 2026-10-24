# A project's page names the other builders whose pages show the same repo,
# which reads every builder's entries by repo. Without an index it scanned
# the whole table.
class AddRepoIndexToEntries < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :entries, [ :repo_name, :user_id ], algorithm: :concurrently
  end
end
