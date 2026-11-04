class ForgetPageVisitorsJob < ApplicationJob
  queue_as :default

  def perform
    Analytics::ForgetVisitorsService.new.call!
  end
end
