class GithubRepo < ApplicationRecord
  belongs_to :user

  validates :github_repo_id, presence: true, uniqueness: { scope: :user_id }
  validates :name, presence: true
  validates :full_name, presence: true

  scope :included_repos, -> { where(included: true) }
end
