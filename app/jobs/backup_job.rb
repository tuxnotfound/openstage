# Nightly at 02:45 UTC, a free slot on the shared box: the other apps dump from 03:00 to 04:15.
class BackupJob < ApplicationJob
  queue_as :default

  def perform
    Backups::RunService.new.call!
  end
end
