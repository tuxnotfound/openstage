class GithubSyncFanoutJob < ApplicationJob
  queue_as :default

  def perform
    # Behind anything a builder is waiting on, such as a webhook's refresh: the
    # worker picks lower numbers first, and those run at the default 0.
    User.active.where.not(github_access_token: nil).find_each do |user|
      GithubSyncJob.set(priority: 10).perform_later(user.id)
    end
  end
end
