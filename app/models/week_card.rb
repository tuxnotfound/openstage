# A builder's card for one week (Monday to Sunday, UTC). Everything shows by
# default, so a row stores only what the builder turned off, the headlines they
# wrote and the post. Deleted with the user by the database (on_delete).
class WeekCard < ApplicationRecord
  STYLES = %w[blueprint].freeze
  LAYOUTS = %w[week active].freeze
  SECTIONS = %w[avatar name github streak totals projects headlines].freeze
  KINDS = %w[built shipped published].freeze
  HEADLINE_LENGTH = 80
  WEEK_PARAM = /\A(\d{4})-W(\d{2})\z/

  belongs_to :user

  validates :week_start, presence: true
  validates :style, inclusion: { in: STYLES }
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

  def to_param
    self.class.param_for(week_start)
  end

  def days
    (week_start..(week_start + 6)).to_a
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
