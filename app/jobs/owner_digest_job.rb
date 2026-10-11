class OwnerDigestJob < ApplicationJob
  queue_as :default

  def perform
    OwnerDigests::SendService.new.call!
  end
end
