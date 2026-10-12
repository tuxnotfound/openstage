# A pull request the builder merged, or a deploy of one of their repos, kept
# so a week card can count them. Deleted with the user or the repo by the
# database (on_delete).
class GithubActivity < ApplicationRecord
  KINDS = %w[pull_request deployment].freeze

  belongs_to :user
  belongs_to :github_repo

  validates :kind, inclusion: { in: KINDS }
  validates :external_id, :occurred_at, presence: true
end
