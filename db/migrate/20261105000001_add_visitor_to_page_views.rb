class AddVisitorToPageViews < ActiveRecord::Migration[7.1]
  def change
    # Takes the place of ip_hash when the hash goes, so a day's visitors can
    # still be counted from the raw rows (Analytics::ForgetVisitorsService).
    add_column :profile_views, :visitor, :uuid
    add_column :project_views, :visitor, :uuid
  end
end
