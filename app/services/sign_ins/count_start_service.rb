module SignIns
  # Counts the start of a sign-in, before GitHub's screen, by the tag the
  # visitor first came with, so /admin tells a click that stops at GitHub
  # from no click at all. One button serves a new builder and a member
  # signing back in, so a member's start counts too; a signed-in click and a
  # bot's never do.
  class CountStartService < ApplicationService
    # The tag of a visitor who came with none, as /admin names their signups.
    UNTAGGED = "unattributed".freeze

    # session: the visitor's, as the sign-in's request phase has it;
    # user_agent: their browser's.
    attr_accessor :session, :user_agent

    private

    def execute
      return if session[:user_id].present? || BotDetector.bot?(user_agent)

      Event.track("sign_in_start", detail: session[:signup_ref].presence || UNTAGGED)
    end
  end
end
