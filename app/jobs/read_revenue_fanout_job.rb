# One job per connected account, so a failure reads everyone else anyway. An
# account deleted these 30 days is not read: nothing shows its revenue.
class ReadRevenueFanoutJob < ApplicationJob
  queue_as :default

  def perform
    RevenueAccount.joins(:user).merge(User.active).find_each { |account| ReadRevenueJob.set(priority: 10).perform_later(account.id) }
  end
end
