# A repo's star count on one day, kept so a week card can tell stars gained.
# Deleted with the repo by the database (on_delete).
class GithubRepoStarCount < ApplicationRecord
  belongs_to :github_repo

  validates :recorded_on, :stars, presence: true
end
