# The Weekly Brief becomes the default week card template. Cards made before
# had no template to choose, so they move to it too; the Timeline stays one
# pick away in the editor.
class MakeBriefTheDefaultWeekCardStyle < ActiveRecord::Migration[7.1]
  def change
    change_column_default :week_cards, :style, from: "timeline", to: "brief"

    up_only do
      execute "UPDATE week_cards SET style = 'brief' WHERE style = 'timeline'"
    end
  end
end
