class GithubRepo < ApplicationRecord
  # Where a project's site visits can come from; nil counts none.
  SITE_SOURCES = %w[script].freeze

  belongs_to :user
  has_many :subscriptions, dependent: :delete_all
  # Deleted with the repo by the database.
  has_many :site_visit_days
  has_many :site_visitors

  validates :github_repo_id, presence: true, uniqueness: { scope: :user_id }
  validates :name, presence: true
  validates :full_name, presence: true
  validates :website_edit, :image_edit, length: { maximum: 500 },
                                        format: { with: %r{\Ahttps?://}i, message: "must start with http:// or https://" }, allow_blank: true
  validates :description_edit, length: { maximum: 280 }
  validates :site_source, inclusion: { in: SITE_SOURCES }, allow_nil: true

  normalizes :description_edit, :website_edit, :image_edit, with: ->(value) { value.strip.presence }

  scope :included_repos, -> { where(included: true) }
  scope :public_repos, -> { where(private_repo: false) }
  scope :site_set_up, -> { where(site_source: "script") }
  # Most site visits ever first, then the oldest: the order Free picks in.
  scope :busiest_site_first, -> {
    left_joins(:site_visit_days).group(:id).order(Arel.sql("COALESCE(SUM(site_visit_days.visits), 0) DESC"), :id)
  }
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

  # Where a project page's button sends a visitor: "visit", its website;
  # "github", the repo, for public repos only. nil without one, or for a
  # website that is not http(s), so no button ever opens another scheme.
  def outbound_url(kind)
    case kind
    when "visit" then website if website.to_s.match?(%r{\Ahttps?://\S+\z}i)
    when "github" then "https://github.com/#{full_name}" unless private_repo?
    end
  end

  # "Live": the project has a website to visit, the builder's own or GitHub's,
  # the same one its Visit button opens.
  def live?
    outbound_url("visit").present?
  end

  # The host Openstage's script counts on: the website's, the one Live means.
  def site_host
    url = outbound_url("visit")
    URI(url).host&.downcase if url
  rescue URI::InvalidURIError
    nil
  end

  # Whether visits to its website count now: every project set up, on Pro;
  # on Free, the busiest one set up, so a downgrade keeps the one that
  # matters most and pauses the rest with their totals kept.
  def counts_site_visits?
    return false unless site_source == "script"

    user.pro? || user.github_repos.site_set_up.busiest_site_first.first == self
  end

  # Shown on its page: switched on, counting, and counted at least once.
  def site_visits_public?
    site_visits_shown? && site_first_visit_at.present? && counts_site_visits?
  end

  # What the project's page still lacks, for the dashboard to list.
  def missing
    { "description" => project_description, "website" => website, "picture" => picture }.select { |_what, value| value.blank? }.keys
  end
end
