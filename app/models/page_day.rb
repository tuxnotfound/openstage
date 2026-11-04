# One day of visits to a builder's page or a project's page, in the builder's
# zone: page is Analytics::CountService::PAGE, or the repo's full name, so the
# day outlives the repo leaving the builder's list. Filled from the raw views
# by Analytics::RollUpService; a visitor's hash goes once it is counted here.
class PageDay < ApplicationRecord
  ADD = Arel.sql("views = page_days.views + EXCLUDED.views, visitors = page_days.visitors + EXCLUDED.visitors").freeze
  private_constant :ADD

  belongs_to :user

  # Adds each row to its day: a day a builder's move to another zone left
  # open can get a second part.
  def self.add(rows)
    upsert_all(rows, unique_by: %i[user_id day page], on_duplicate: ADD) if rows.any?
  end
end
