# One click on a project page's Visit (the project's website) or View on
# GitHub button. Never the builder's own, never a bot's.
class ProjectClick < ApplicationRecord
  KINDS = %w[visit github].freeze

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }
end
