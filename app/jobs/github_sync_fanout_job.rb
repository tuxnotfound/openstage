class GithubSyncFanoutJob < ApplicationJob
  queue_as :default

  def perform
    User.active.where.not(github_access_token: nil).find_each do |user|
      GithubSyncJob.perform_later(user.id)
    end
  end
end
