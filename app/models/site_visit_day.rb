# One day of visits to a project's website, in the builder's zone: page views
# and visitors, a visitor being one browser on one day. No visitor's record
# outlives the day; these totals are what stays.
class SiteVisitDay < ApplicationRecord
  belongs_to :github_repo
end
