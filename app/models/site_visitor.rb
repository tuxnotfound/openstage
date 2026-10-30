# One visitor to a project's website on one day, as a hash of their IP that
# cannot be matched across days, with their page views, so the day counts them
# once and caps them, and their page loads, so their source and ref tag count
# once, on the first. Deleted within two days (SiteVisits::ForgetVisitorsService).
class SiteVisitor < ApplicationRecord
  belongs_to :github_repo
end
