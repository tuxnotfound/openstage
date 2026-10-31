# One click on a project page's Visit (the project's website) or View on
# GitHub button. Never the builder's own, never a bot's.
class ProjectClick < ApplicationRecord
  KINDS = %w[visit github].freeze

  # Holds no visitor hash any more (ClearClickAndBadgeIpHashes). The column is
  # dropped in the next release, once no running code writes it.
  self.ignored_columns += %w[ip_hash]

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
end
