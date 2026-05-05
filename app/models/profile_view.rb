class ProfileView < ApplicationRecord
  belongs_to :user

  scope :this_week, -> { where(viewed_at: 1.week.ago..) }
  scope :last_7_days, -> { where(viewed_at: 7.days.ago..) }
  scope :last_30_days, -> { where(viewed_at: 30.days.ago..) }

  def self.daily_counts(days:)
    start = days.days.ago.to_date
    grouped = where(viewed_at: start.beginning_of_day..)
                .group("DATE(viewed_at AT TIME ZONE 'UTC')")
                .count
    # AR returns Date objects as hash keys from a DATE group; use Date for lookup
    # and convert to string keys for the output hash.
    (0...days).each_with_object({}) do |i, h|
      date = start + i
      h[date.to_s] = grouped[date] || 0
    end
  end

  def self.unique_visitor_count(since:)
    where(viewed_at: since..).distinct.count(:ip_hash)
  end

  def self.top_countries(limit: 3)
    where.not(country: [ nil, "" ])
         .group(:country)
         .order("count_all DESC")
         .limit(limit)
         .count
  end

  def self.top_referrers(limit: 5)
    where.not(referrer: [ nil, "" ])
         .group(:referrer)
         .order("count_all DESC")
         .limit(limit)
         .count
  end
end
