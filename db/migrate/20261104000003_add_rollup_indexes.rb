class AddRollupIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    # The raw rows are read by time from where a builder's totals stop.
    add_index :project_views, %i[user_id viewed_at], algorithm: :concurrently
    add_index :project_clicks, %i[user_id clicked_at], algorithm: :concurrently

    # Only the rows that still hold a hash, a few days of them, so the nightly
    # forgetting does not read the whole table.
    add_index :profile_views, :viewed_at, where: "ip_hash IS NOT NULL", name: "index_profile_views_holding_a_hash", algorithm: :concurrently
    add_index :project_views, :viewed_at, where: "ip_hash IS NOT NULL", name: "index_project_views_holding_a_hash", algorithm: :concurrently
  end
end
