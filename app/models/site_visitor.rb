# One visitor to a project's website on one day, as a hash of their IP that
# cannot be matched across days, with their page views, so the day counts them
# once and caps them. Deleted once the day is over (SiteVisits::ForgetVisitorsService).
class SiteVisitor < ApplicationRecord
  belongs_to :github_repo
end
