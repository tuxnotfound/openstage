# No week card template leads with one day any more: the Weekly Brief that did
# is parked on its own branch.
class RemoveLeadOnFromWeekCards < ActiveRecord::Migration[7.1]
  def change
    remove_column :week_cards, :lead_on, :date
  end
end
