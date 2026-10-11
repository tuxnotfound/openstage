module Users
  # Takes an account offline. Signing in within 30 days restores it, and
  # Users::PurgeDeletedService deletes it for good after that. A monthly plan
  # stops renewing at once, so a deleted account is never billed again.
  class DeleteService < ApplicationService
    attr_accessor :user

    validates :user, presence: true

    private

    def execute
      subscription_id = user.stripe_subscription_id
      user.soft_delete!
      return if subscription_id.blank?

      after_commit { StopRenewalJob.perform_later(subscription_id) }
    end
  end
end
