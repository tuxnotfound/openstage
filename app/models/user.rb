class User < ApplicationRecord
  include Contacts
  include GithubToken

  USERNAME_CHANGE_COOLDOWN = 30.days

  # Paths the app routes itself — must never be claimable as a profile username,
  # or they would shadow (or be shadowed by) those routes.
  RESERVED_USERNAMES = %w[
    about pricing blog llms feed dashboard settings analytics billing checkout
    sync auth og badge embed embeds claim claim-username sitemap robots favicon
    webhooks sign_out signin signup login logout register admin api app www
    help support docs terms privacy contact status new edit me root public
    assets up entries github_repos e recap _deploy_check subscriptions subscribe weekly_email week
  ].freeze

  has_many :entries, dependent: :destroy
  has_many :events, dependent: :delete_all
  has_many :subscriptions, dependent: :delete_all
  has_many :github_repos, dependent: :destroy
  has_many :site_visit_days, through: :github_repos
  has_many :sync_logs, dependent: :destroy
  has_many :profile_views, dependent: :destroy
  has_many :project_views, dependent: :delete_all
  has_many :project_clicks, dependent: :delete_all
  has_many :entry_clicks, dependent: :destroy
  has_many :badge_impressions, dependent: :destroy

  scope :active, -> { where(deleted_at: nil) }
  # Everyone but the owner, by owner?'s rule, so the feed shows the others.
  scope :not_owner, -> {
    if (uid = ENV["OWNER_GITHUB_UID"].presence)
      where.not(github_uid: uid)
    else
      where("users.github_username IS NULL OR LOWER(users.github_username) <> ?", ENV.fetch("OWNER_GITHUB_USERNAME", "tuxnotfound").downcase)
    end
  }
  # Everyone the numbers count: test accounts (internal) stay out of /admin,
  # the owner digest and the gates.
  scope :counted, -> { active.where(internal: false) }

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

  # Where a signup came from, captured once at first touch. Anything else is
  # recorded as "direct" so the denominator is never silently incomplete.
  # "bio" is the link in the founder's X profile, so reply-first presence on X
  # is attributed separately from recap posts.
  # "launch" is the tag on the links in the soft-launch posts. A launch venue
  # with a gate read of its own gets its own tag: "peerlist" (the Gate 1
  # retry) and "producthunt" (the card). The free boards listed in the
  # Product Hunt week get one each, so a listing's signups never land as
  # "direct". "digest" is the subscriber digest. "reddit" is every link
  # posted on Reddit.
  REFS = %w[recap badge footer feed claim bio launch peerlist producthunt
            devhunt saashub alternativeto digest reddit].freeze
  DEFAULT_REF = "direct".freeze

  def self.normalize_ref(value)
    ref = value.to_s.downcase.strip
    REFS.include?(ref) ? ref : DEFAULT_REF
  end

  def self.from_github_omniauth(auth)
    user = find_or_initialize_by(github_uid: auth.uid)
    user.github_username = auth.info.nickname
    user.adopt_github_token(auth.credentials.token, auth.extra&.scope)
    user.display_name ||= auth.info.name.presence || auth.info.nickname
    user.avatar_url ||= auth.info.image
    user.username ||= auth.info.nickname
    user.email ||= auth.info.email.presence
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

  # Gates the owner-only surfaces (/_deploy_check, /admin).
  #
  # Prefers the immutable numeric GitHub id. github_username is rewritten from
  # the OAuth nickname on every sign-in, and GitHub frees a login for
  # re-registration when an account is renamed, so the handle alone would hand
  # ownership to whoever claimed it next.
  # The zone the builder's page counts days in; UTC until one is known.
  def zone
    ActiveSupport::TimeZone[time_zone.to_s] || ActiveSupport::TimeZone["UTC"]
  end

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

  # Suggestions for tagging an entry with a project: synced repos plus any
  # custom project names already used, so re-tagging collapses onto one filter.
  def project_names
    (github_repos.pluck(:full_name) +
     entries.where.not(repo_name: nil).distinct.pluck(:repo_name)).uniq.sort
  end

  def public_github_commits_count
    entries.publicly_visible.commits.count
  end

  def public_activity_streak
    activity_days = entries.publicly_visible.without_hidden_commits
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
