class BadgeImpression < ApplicationRecord
  belongs_to :user

  KINDS = %w[badge embed].freeze
  validates :kind, inclusion: { in: KINDS }
  validates :viewed_at, presence: true

  scope :badges, -> { where(kind: "badge") }
  scope :embeds, -> { where(kind: "embed") }
end
