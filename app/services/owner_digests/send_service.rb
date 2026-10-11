module OwnerDigests
  # F4: Monday's email to me with the week's numbers from /admin and the failed
  # job count, so a quiet week or a broken job reaches my inbox without my
  # opening the dashboard. It replaces separate alerting, so it goes out every
  # week, even an empty one.
  class SendService < ApplicationService
    WINDOW = 7.days

    attr_reader :numbers

    private

    def execute
      @numbers = funnel_numbers.merge(
        failed_jobs: SolidQueue::FailedExecution.count,
        failed_job_classes: SolidQueue::FailedExecution.joins(:job).group("solid_queue_jobs.class_name").count
      )
      SystemMailer.owner_digest(@numbers).deliver_later
    end

    def funnel_numbers
      signups = User.active.where(created_at: since..).where.not(id: owner_ids)
      {
        signups_by_ref: signups.group(:signup_ref).count.transform_keys { |ref| ref.presence || "unattributed" },
        activated: signups.joins(:entries).distinct.count,
        subscribes: Subscription.confirmed.where(confirmed_at: since..).count,
        recap_intents: builders_who("recap_intent"),
        weekly_mailed: User.where(weekly_email_sent_at: since..).where.not(id: owner_ids).count,
        weekly_opened: builders_who("recap_from_email")
      }
    end

    def since
      @since ||= WINDOW.ago
    end

    # User#owner? holds the rule; at this scale reading every user is cheap.
    def owner_ids
      @owner_ids ||= User.active.find_each.select(&:owner?).map(&:id)
    end

    def builders_who(event)
      Event.since(since).named(event).where.not(user_id: owner_ids).distinct.count(:user_id)
    end
  end
end
