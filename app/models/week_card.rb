# A builder's card for one week, Monday to Sunday in the card's time zone.
# Almost everything shows by default, so a row stores only what the builder
# turned off, the headlines and goal they wrote, and the post. Deleted with the
# user by the database (on_delete).
class WeekCard < ApplicationRecord
  STYLES = %w[timeline].freeze
  THEMES = %w[light dark].freeze
  LAYOUTS = %w[week active].freeze
  SECTIONS = %w[avatar name github building streak totals compare projects headlines goal audience hours code repos].freeze
  # Small numbers can work against a builder, so audience starts off.
  HIDDEN_AT_FIRST = %w[audience].freeze
  KINDS = %w[built shipped published].freeze
  HEADLINE_LENGTH = 80
  GOAL_LENGTH = 60
  WEEK_PARAM = /\A(\d{4})-W(\d{2})\z/

  belongs_to :user

  attribute :hidden_sections, :jsonb, default: -> { HIDDEN_AT_FIRST.dup }

  normalizes :next_goal, with: ->(goal) { goal.to_s.squish.first(GOAL_LENGTH).presence }
  # The browser names the zone. One Rails does not know falls back to UTC
  # rather than stop the card from saving.
  normalizes :time_zone, with: ->(zone) { ActiveSupport::TimeZone[zone.to_s] ? zone.to_s : nil }

  validates :week_start, presence: true
  validates :style, inclusion: { in: STYLES }
  validates :theme, inclusion: { in: THEMES }
  validates :layout, inclusion: { in: LAYOUTS }
  validates :post_text, length: { maximum: 2000 }
  validate :week_starts_on_monday

  # "2026-W41" to that week's Monday; nil for anything else.
  def self.week_start_for(param)
    match = WEEK_PARAM.match(param.to_s)
    return unless match

    Date.commercial(match[1].to_i, match[2].to_i, 1)
  rescue Date::Error
    nil
  end

  def self.param_for(week_start)
    week_start.strftime("%G-W%V")
  end

  # The zone of the builder's last saved card, so a new week starts in it.
  def self.last_time_zone_for(user)
    where(user: user).where.not(time_zone: nil).order(updated_at: :desc).pick(:time_zone)
  end

  def to_param
    self.class.param_for(week_start)
  end

  def days
    (week_start..(week_start + 6)).to_a
  end

  # The browser's zone when the builder last saved; UTC until then.
  def zone
    ActiveSupport::TimeZone[time_zone.to_s] || ActiveSupport::TimeZone["UTC"]
  end

  # Monday 00:00 to the next Monday 00:00 in the card's zone; adding calendar
  # days keeps a daylight-saving change inside the week.
  def time_range
    start = zone.local(week_start.year, week_start.month, week_start.day)
    start...(start + 7.days)
  end

  def shows?(section)
    !hidden_sections.include?(section)
  end

  def shows_project?(name)
    !hidden_projects.include?(name)
  end

  # The form sends every section as "1" or "0", so an unticked box is a "0".
  def sections=(ticks)
    self.hidden_sections = ticks.to_h.select { |section, on| SECTIONS.include?(section) && on.to_s == "0" }.keys
  end

  def projects=(ticks)
    self.hidden_projects = ticks.to_h.select { |_name, on| on.to_s == "0" }.keys.map(&:to_s)
  end

  # { "2026-10-06" => { "text" => "...", "kind" => "built" } }, only for days of
  # this week; a blank text clears that day.
  def headlines=(by_day)
    allowed = days.map(&:iso8601)
    kept = by_day.to_h.each_with_object({}) do |(day, headline), result|
      text = headline.to_h["text"].to_s.squish.first(HEADLINE_LENGTH)
      next unless allowed.include?(day.to_s) && text.present?

      kind = headline.to_h["kind"].to_s
      result[day.to_s] = { "text" => text, "kind" => KINDS.include?(kind) ? kind : "built" }
    end
    super(kept)
  end

  def headline_on(day)
    headlines[day.iso8601]
  end

  private

  def week_starts_on_monday
    errors.add(:week_start, "must be a Monday") if week_start && !week_start.monday?
  end
end
