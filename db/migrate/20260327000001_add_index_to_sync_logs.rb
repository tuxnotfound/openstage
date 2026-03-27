class AddIndexToSyncLogs < ActiveRecord::Migration[7.1]
  def change
    add_index :sync_logs, [ :user_id, :source, :ran_at ],
              name: "index_sync_logs_on_user_source_ran_at"
  end
end
