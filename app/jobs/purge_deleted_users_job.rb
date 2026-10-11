class PurgeDeletedUsersJob < ApplicationJob
  queue_as :default

  def perform
    Users::PurgeDeletedService.new.call!
  end
end
