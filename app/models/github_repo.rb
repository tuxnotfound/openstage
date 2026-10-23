class GithubRepo < ApplicationRecord
  belongs_to :user

  validates :github_repo_id, presence: true, uniqueness: { scope: :user_id }
  validates :name, presence: true
  validates :full_name, presence: true
  validates :website_edit, :image_edit, length: { maximum: 500 },
                                        format: { with: %r{\Ahttps?://}i, message: "must start with http:// or https://" }, allow_blank: true
  validates :description_edit, length: { maximum: 280 }

  normalizes :description_edit, :website_edit, :image_edit, with: ->(value) { value.strip.presence }

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

  # What a project's page says it is: the builder's own words, which win once
  # written; else GitHub's description; else the README's first line.
  def project_description
    description_edit.presence || description.presence || readme_line.presence
  end

  def website
    website_edit.presence || homepage.presence
  end

  def picture
    image_edit.presence || preview_image_url.presence
  end

  # "Live" reads from GitHub only: the repo has a website there.
  def live?
    homepage.present?
  end

  # What the project's page still lacks, for the dashboard to list.
  def missing
    { "description" => project_description, "website" => website, "picture" => picture }.select { |_what, value| value.blank? }.keys
  end
end
