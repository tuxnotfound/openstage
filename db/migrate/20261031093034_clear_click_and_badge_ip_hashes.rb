# Clicks and the badge's and embed's views never read their visitor's hash
# and keep none from now on, so the hashes kept so far go too. The columns
# stay until the next release: the code still running while this one deploys
# writes them. One way, as the hashes cannot come back.
class ClearClickAndBadgeIpHashes < ActiveRecord::Migration[7.1]
  def up
    %w[entry_clicks project_clicks badge_impressions].each do |table|
      execute "UPDATE #{table} SET ip_hash = NULL WHERE ip_hash IS NOT NULL"
    end
  end
end
