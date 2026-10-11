class WeeklyEmailJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.active.find_by(id: user_id)
    return unless user

    WeeklyEmails::SendService.new(user: user).call!
  end
end
