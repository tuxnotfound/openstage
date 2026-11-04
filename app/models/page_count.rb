# One day's count of one value on a builder's pages, in the builder's zone,
# for a page as PageDay names it: a page's views by source and by country, a
# project's Visit and View on GitHub buttons, and the badge's and embed's
# views by the site that showed them, those on the builder's own page.
# Filled from the raw rows by Analytics::RollUpService.
class PageCount < ApplicationRecord
  KINDS = %w[source country button badge embed].freeze
  ADD = Arel.sql("count = page_counts.count + EXCLUDED.count").freeze
  private_constant :ADD

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }

  scope :buttons, -> { where(kind: "button") }

  # Adds each row to its count, as PageDay.add does.
  def self.add(rows)
    upsert_all(rows, unique_by: :index_page_counts_once_a_day, on_duplicate: ADD) if rows.any?
  end
end
