# The day the builder picked to lead the week card with. Without one, the card
# picks by its own rule (WeekCards::PickLeadService).
class AddLeadOnToWeekCards < ActiveRecord::Migration[7.1]
  def change
    add_column :week_cards, :lead_on, :date
  end
end
