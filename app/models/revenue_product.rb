# A product in a builder's payment account (Revenue::ImportProductsService),
# and the one project its revenue counts for, if any
# (Revenue::CountProductService).
class RevenueProduct < ApplicationRecord
  belongs_to :revenue_account
  belongs_to :github_repo, optional: true

  validates :external_id, presence: true, uniqueness: { scope: :revenue_account_id }
  validates :name, presence: true

  # Products on sale first, archived ones after, each by name.
  scope :listed, -> { order(active: :desc, name: :asc) }
end
