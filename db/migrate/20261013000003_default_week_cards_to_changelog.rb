# Changelog is the template a new card starts on. Cards already on the
# timeline keep it.
class DefaultWeekCardsToChangelog < ActiveRecord::Migration[7.1]
  def change
    change_column_default :week_cards, :style, from: "timeline", to: "changelog"
  end
end
