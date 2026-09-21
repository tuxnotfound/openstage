# Behaviour the gates in REBIRTH_PLAN.md are scored on, and nothing else.
# Every name is something a person did. A page that merely rendered is not an
# event, which is why there is no "recap generated".
class Event < ApplicationRecord
  belongs_to :user, optional: true

  NAMES = %w[
    seen
    ref_visit
    recap_opened recap_quiet recap_picked recap_copied recap_intent
  ].freeze

  # Only these may be reported by the browser; the rest are recorded server-side.
  CLIENT_NAMES = %w[recap_copied recap_intent].freeze
  INTENT_DETAILS = %w[x bluesky].freeze

  validates :name, inclusion: { in: NAMES }

  scope :since, ->(time) { where(day: time.to_date..) }
  scope :named, ->(name) { where(name: name) }

  # Never raises into a request: losing a metric is better than a 500.
  def self.track(name, user: nil, detail: "")
    return unless NAMES.include?(name.to_s)

    insert(
      { user_id: user&.id, name: name.to_s, detail: detail.to_s.first(40), day: Date.current, created_at: Time.current },
      unique_by: :index_events_once_per_user_per_day
    )
  rescue StandardError => e
    Rails.logger.warn("Event.track failed: #{e.class} #{e.message}")
    nil
  end

  # Users in the scope who were seen on a day after the day they signed up.
  def self.returned_user_ids(users)
    named("seen").joins(:user).merge(users)
                 .where("events.day > DATE(users.created_at)").distinct.pluck(:user_id)
  end

  # Users seen between day 7 and day 13 after signup: the north-star number.
  def self.second_week_user_ids(users)
    named("seen").joins(:user).merge(users)
                 .where("events.day >= DATE(users.created_at) + 7 AND events.day < DATE(users.created_at) + 14")
                 .distinct.pluck(:user_id)
  end
end
