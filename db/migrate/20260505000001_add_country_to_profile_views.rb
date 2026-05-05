class AddCountryToProfileViews < ActiveRecord::Migration[7.1]
  def change
    add_column :profile_views, :country, :string
    add_index :profile_views, [ :user_id, :country ]
  end
end
