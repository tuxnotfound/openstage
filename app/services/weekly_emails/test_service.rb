module WeeklyEmails
  # Both of F2's emails for the owner's own week, sent to the owner now, to
  # read them in a real inbox before a Friday send. It claims nothing, so the
  # Friday send still goes out, and it ignores the quiet threshold. The digest
  # goes to a subscription that is never saved, so no count moves; its
  # unsubscribe link leads nowhere.
  class TestService < ApplicationService
    TOKEN = "test"

    attr_accessor :user

    validates :user, presence: true
    validate :user_has_email

    private

    def execute
      deliver(WeeklyMailer.week_ready(user))
      deliver(WeeklyMailer.digest(Subscription.new(user: user, email: user.email, token: TOKEN)))
    end

    # Marked, so a test never threads with a real Friday email in the inbox.
    def deliver(delivery)
      delivery.subject = "[Test] #{delivery.subject}"
      delivery.deliver_now
    end

    def user_has_email
      return if user.nil? || user.email.present?

      errors.add(:base, "Your account has no email yet. Sign out and back in to capture it from GitHub.")
    end
  end
end
