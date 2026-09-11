class User < ApplicationRecord
  USERNAME_CHANGE_COOLDOWN = 30.days

  # Paths the app routes itself — must never be claimable as a profile username,
  # or they would shadow (or be shadowed by) those routes.
  RESERVED_USERNAMES = %w[
    about pricing blog llms feed dashboard settings analytics billing checkout
    sync auth og badge embed embeds claim claim-username sitemap robots favicon
    webhooks sign_out signin signup login logout register admin api app www
    help support docs terms privacy contact status new edit me root public
    assets up entries github_repos e recap _deploy_check
  ].freeze

  has_many :entries, dependent: :destroy
  has_many :github_repos, dependent: :destroy
  has_many :sync_logs, dependent: :destroy
  has_many :profile_views, dependent: :destroy
  has_many :entry_clicks, dependent: :destroy
  has_many :badge_impressions, dependent: :destroy

  scope :active, -> { where(deleted_at: nil) }

  validates :github_uid, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-zA-Z0-9_-]+\z/, message: "only allows letters, numbers, hyphens, and underscores" },
                       length: { minimum: 2, maximum: 39 }

  # website_url is rendered into an href on the public profile, so anything but
  # http(s) is a script-injection vector (javascript:, data:).
  validates :website_url, format: { with: %r{\Ahttps?://}i, message: "must start with http:// or https://" },
                          allow_blank: true
  validate :username_change_cooldown, if: :username_changed?
  validate :username_not_reserved, if: :username_changed?

  before_save :track_username_change, if: -> { persisted? && will_save_change_to_username? }

  def self.from_github_omniauth(auth)
    user = find_or_initialize_by(github_uid: auth.uid)
    user.github_username = auth.info.nickname
    user.github_access_token = auth.credentials.token
    user.display_name ||= auth.info.name.presence || auth.info.nickname
    user.avatar_url ||= auth.info.image
    user.username ||= auth.info.nickname
    user
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def can_change_username?
    username_changed_at.nil? || username_changed_at < USERNAME_CHANGE_COOLDOWN.ago
  end

  def next_username_change_at
    return nil if can_change_username?
    username_changed_at + USERNAME_CHANGE_COOLDOWN
  end

  def last_synced_at(source:)
    sync_logs.where(source: source, status: :success).maximum(:ran_at)
  end

  def pro?
    pro
  end

  # Gates the owner-only surfaces (/recap, /_deploy_check). Temporary: C1 opens
  # the recap picker to every user and this shrinks back to diagnostics.
  #
  # Prefers the immutable numeric GitHub id. github_username is rewritten from
  # the OAuth nickname on every sign-in, and GitHub frees a login for
  # re-registration when an account is renamed, so the handle alone would hand
  # ownership to whoever claimed it next.
  def owner?
    if (uid = ENV["OWNER_GITHUB_UID"].presence)
      return github_uid.to_s == uid
    end

    github_username.present? &&
      github_username.casecmp?(ENV.fetch("OWNER_GITHUB_USERNAME", "tuxnotfound"))
  end

  def can_pin?
    pro? && entries.pinned_entries.count < 3
  end

  def can_set_private?
    pro?
  end

  def public_entries_count
    entries.publicly_visible.count
  end

  def public_milestones_count
    entries.publicly_visible.where(entry_type: :milestone).count
  end

  # Suggestions for tagging an entry with a project: synced repos plus any
  # custom project names already used, so re-tagging collapses onto one filter.
  def project_names
    (github_repos.pluck(:full_name) +
     entries.where.not(repo_name: nil).distinct.pluck(:repo_name)).uniq.sort
  end

  def public_recent_commits_count(window: 30.days)
    entries.publicly_visible.where(source: :github, entry_type: :shipped, occurred_at: window.ago..).count
  end

  def public_github_commits_count
    entries.publicly_visible.where(source: :github, entry_type: :shipped).count
  end

  def public_activity_streak
    activity_days = entries.publicly_visible
                         .where.not(occurred_at: nil)
                         .group("DATE(occurred_at AT TIME ZONE 'UTC')")
                         .count
                         .keys
                         .map(&:to_date)
                         .sort

    return 0 if activity_days.empty?

    streak = 1
    current_day = activity_days.last

    activity_days[0...-1].reverse_each do |day|
      break unless day == current_day - 1.day

      streak += 1
      current_day = day
    end

    streak
  end

  # Consecutive calendar days (UTC) with at least one non-hidden entry.
  # Includes private entries — counts all activity, any type, any source.
  # Returns 0 if today *and* yesterday both have no entries.
  def current_streak
    today = Date.current

    dated = entries.visible
                   .where.not(occurred_at: nil)
                   .group("DATE(occurred_at AT TIME ZONE 'UTC')")
                   .count
                   .keys
                   .map(&:to_date)
                   .to_set

    return 0 unless dated.include?(today) || dated.include?(today - 1.day)

    check = dated.include?(today) ? today : today - 1.day
    streak = 0
    while dated.include?(check)
      streak += 1
      check -= 1.day
    end
    streak
  end

  private

  def username_change_cooldown
    return if username_changed_at.nil?
    errors.add(:username, "can only be changed once every 30 days") unless can_change_username?
  end

  def username_not_reserved
    return if username.blank?
    errors.add(:username, "is reserved") if RESERVED_USERNAMES.include?(username.downcase)
  end

  def track_username_change
    self.username_changed_at = Time.current
  end
end
