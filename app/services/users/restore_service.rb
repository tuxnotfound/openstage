module Users
  # Brings back an account deleted in the last 30 days, which is what signing
  # in during them does. A monthly plan that deleting set to stop renews again,
  # so a restored account does not lose Pro at the end of the period.
  class RestoreService < ApplicationService
    attr_accessor :user

    validates :user, presence: true
    validate :user_deleted

    private

    def execute
      user.update!(deleted_at: nil)
      subscription_id = user.stripe_subscription_id
      return if subscription_id.blank?

      after_commit { SetRenewalJob.perform_later(subscription_id, true) }
    end

    def user_deleted
      errors.add(:user, "is not deleted") if user && !user.deleted?
    end
  end
end
