class GithubRepo < ApplicationRecord
  belongs_to :user

  validates :github_repo_id, presence: true, uniqueness: { scope: :user_id }
  validates :name, presence: true
  validates :full_name, presence: true

  scope :included_repos, -> { where(included: true) }
  scope :public_repos, -> { where(private_repo: false) }
  # Repos with work on Openstage, shown or hidden: the projects a builder
  # chooses between on the dashboard.
  scope :with_entries, -> {
    where("EXISTS (SELECT 1 FROM entries WHERE entries.user_id = github_repos.user_id AND entries.repo_name = github_repos.full_name)")
  }

  # Repos under different owners can share a name, so Settings names the owner
  # of every repo that is not the builder's own.
  def owner_login
    full_name.split("/").first
  end

  def owned_by_user?
    owner_login.casecmp?(user.github_username.to_s)
  end
end
