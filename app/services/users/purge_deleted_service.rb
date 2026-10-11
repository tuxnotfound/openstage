module Users
  # Deletes for good the accounts deleted more than 30 days ago, with
  # everything they own. Settings promises those 30 days, and signing in
  # during them restores the account (SessionsController).
  class PurgeDeletedService < ApplicationService
    GRACE = 30.days

    attr_reader :purged

    private

    def execute
      users = User.where(deleted_at: ...GRACE.ago)
      @purged = users.count
      users.find_each(&:destroy!)
    end
  end
end
