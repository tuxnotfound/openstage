# A payment provider a builder connects, so their projects can show MRR from
# it: Stripe for now, one account per provider (Revenue::ConnectService). Its
# key only reads, and is encrypted at rest, as GitHub's token is.
class RevenueAccount < ApplicationRecord
  PROVIDERS = %w[stripe].freeze

  belongs_to :user
  # The database deletes them with the account too.
  has_many :revenue_products, dependent: :delete_all

  encrypts :api_key

  validates :provider, inclusion: { in: PROVIDERS }, uniqueness: { scope: :user_id }
  validates :api_key, presence: true

  # How Stripe's dashboard tells keys apart, so the builder knows which one
  # Openstage holds.
  def key_ending
    api_key.last(4)
  end
end
