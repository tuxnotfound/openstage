class BadgeImpression < ApplicationRecord
  belongs_to :user

  KINDS = %w[badge embed].freeze
  validates :kind, inclusion: { in: KINDS }
  validates :viewed_at, presence: true

  # Holds no visitor hash any more (ClearClickAndBadgeIpHashes). The column is
  # dropped in the next release, once no running code writes it.
  self.ignored_columns += %w[ip_hash]

  scope :badges, -> { where(kind: "badge") }
  scope :embeds, -> { where(kind: "embed") }
end
