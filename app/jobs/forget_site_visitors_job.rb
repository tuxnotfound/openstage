class ForgetSiteVisitorsJob < ApplicationJob
  queue_as :default

  def perform
    SiteVisits::ForgetVisitorsService.new.call!
  end
end
