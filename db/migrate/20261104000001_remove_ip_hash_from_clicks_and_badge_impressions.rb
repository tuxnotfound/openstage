# Emptied by ClearClickAndBadgeIpHashes, and unwritten by any running code
# since the 2026-11-03 deploy. A rollback brings the columns back empty.
class RemoveIpHashFromClicksAndBadgeImpressions < ActiveRecord::Migration[7.1]
  def change
    remove_column :entry_clicks, :ip_hash, :string
    remove_column :project_clicks, :ip_hash, :string
    remove_column :badge_impressions, :ip_hash, :string
  end
end
