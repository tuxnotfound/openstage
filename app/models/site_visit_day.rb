# One day of visits to a project's website, in the builder's zone: page views
# and visitors, a visitor being one IP address, or one IPv6 network, on one
# day (SiteVisits::RecordService#network). No visitor's record
# outlives the day; these totals are what stays.
class SiteVisitDay < ApplicationRecord
  belongs_to :github_repo
end
