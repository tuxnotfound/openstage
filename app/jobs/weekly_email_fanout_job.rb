# One job per builder, so a failure mails everyone else anyway.
class WeeklyEmailFanoutJob < ApplicationJob
  queue_as :default

  def perform
    User.active.find_each { |user| WeeklyEmailJob.perform_later(user.id) }
  end
end
