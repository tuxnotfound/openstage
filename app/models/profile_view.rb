class ProfileView < ApplicationRecord
  belongs_to :user

  scope :this_week, -> { where(viewed_at: 1.week.ago..) }

  def self.top_referrers(limit: 5)
    where.not(referrer: [nil, ""])
         .group(:referrer)
         .order("count_all DESC")
         .limit(limit)
         .count
  end
end
