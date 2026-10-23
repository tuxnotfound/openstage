module Subscriptions
  # A reader asks for a builder's updates, or one project's, by email. The
  # row waits for the link in the confirmation mail; asking again within
  # Subscription::RESEND_AFTER sends nothing, and an address already
  # confirmed gets nothing, so the form says the same whoever is on the list.
  class RequestService < ApplicationService
    # github_repo: the project followed; nil for the builder's whole page.
    attr_accessor :user, :github_repo, :email
    attr_reader :subscription

    validates :user, presence: true

    private

    def execute
      @subscription = user.subscriptions.find_or_initialize_by(github_repo: github_repo, email: email)
      if subscription.new_record? && subscription.invalid?
        absorb_errors(subscription)
        return
      end
      return unless subscription.confirmation_due?

      subscription.update!(confirmation_sent_at: Time.current)
      SubscriptionMailer.confirm(subscription).deliver_later
    end
  end
end
