# The builder's time zone, which their page counts days in. It was read from
# their last saved week card; the week card is gone, so each builder keeps the
# zone of that card here.
class AddTimeZoneToUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :time_zone, :string
    execute <<~SQL
      UPDATE users SET time_zone = latest.time_zone
      FROM (SELECT DISTINCT ON (user_id) user_id, time_zone FROM week_cards
            WHERE time_zone IS NOT NULL ORDER BY user_id, updated_at DESC) AS latest
      WHERE latest.user_id = users.id
    SQL
  end

  def down
    remove_column :users, :time_zone
  end
end
