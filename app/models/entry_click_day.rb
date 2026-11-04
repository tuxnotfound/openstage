# One day's clicks on an entry's link, in the builder's zone. Kept by entry,
# so they count for the project the entry is in now, and go with it. Filled
# from EntryClick by Analytics::RollUpService.
class EntryClickDay < ApplicationRecord
  ADD = Arel.sql("clicks = entry_click_days.clicks + EXCLUDED.clicks").freeze
  private_constant :ADD

  belongs_to :user
  belongs_to :entry

  # Adds each row to its day, as PageDay.add does.
  def self.add(rows)
    upsert_all(rows, unique_by: %i[entry_id day], on_duplicate: ADD) if rows.any?
  end
end
