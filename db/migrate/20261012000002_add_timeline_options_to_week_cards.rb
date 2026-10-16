# The timeline card: light or dark, the builder's goal for next week, and the
# time zone the card counts days and hours in. The browser sends the zone, so
# a commit at 23:30 in Lisbon lands on the right day and hour.
class AddTimelineOptionsToWeekCards < ActiveRecord::Migration[7.1]
  def change
    add_column :week_cards, :theme, :string, null: false, default: "light"
    add_column :week_cards, :next_goal, :string
    add_column :week_cards, :time_zone, :string
    change_column_default :week_cards, :style, from: "blueprint", to: "timeline"

    up_only do
      execute "UPDATE week_cards SET style = 'timeline' WHERE style = 'blueprint'"
    end
  end
end
