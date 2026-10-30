class AddLoadsToSiteVisitors < ActiveRecord::Migration[7.1]
  def change
    # A visitor's page loads on the day, the views the script sends with a
    # referrer: their source and ref tag count on the first one, whether or
    # not it reaches Openstage before a page change the site made at once.
    add_column :site_visitors, :loads, :integer, null: false, default: 0
  end
end
