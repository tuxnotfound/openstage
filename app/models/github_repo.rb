class GithubRepo < ApplicationRecord
  belongs_to :user

  validates :github_repo_id, presence: true, uniqueness: { scope: :user_id }
  validates :name, presence: true
  validates :full_name, presence: true

  scope :included_repos, -> { where(included: true) }
  scope :public_repos, -> { where(private_repo: false) }

  # Repos under different owners can share a name, so Settings names the owner
  # of every repo that is not the builder's own.
  def owner_login
    full_name.split("/").first
  end

  def owned_by_user?
    owner_login.casecmp?(user.github_username.to_s)
  end
end
