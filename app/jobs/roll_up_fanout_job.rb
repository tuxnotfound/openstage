# One job per builder, so a failure rolls up everyone else anyway. Every
# builder: an account deleted these 30 days holds visitors' hashes too, which
# go only once rolled up.
class RollUpFanoutJob < ApplicationJob
  queue_as :default

  def perform
    User.find_each { |user| RollUpJob.set(priority: 10).perform_later(user.id) }
  end
end
