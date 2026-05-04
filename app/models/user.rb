class User < ApplicationRecord
  USERNAME_CHANGE_COOLDOWN = 30.days

  has_many :entries, dependent: :destroy
  has_many :github_repos, dependent: :destroy
  has_many :sync_logs, dependent: :destroy
  has_many :profile_views, dependent: :destroy

  scope :active, -> { where(deleted_at: nil) }

  validates :github_uid, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-zA-Z0-9_-]+\z/, message: "only allows letters, numbers, hyphens, and underscores" },
                       length: { minimum: 2, maximum: 39 }
  validate :username_change_cooldown, if: :username_changed?

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

  private

  def username_change_cooldown
    return if username_changed_at.nil?
    errors.add(:username, "can only be changed once every 30 days") unless can_change_username?
  end

  def track_username_change
    self.username_changed_at = Time.current
  end
end
