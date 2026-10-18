# Four numbers, deliberately. The gates in REBIRTH_PLAN.md are scored off this
# page, and anything beyond what a gate needs is a distraction from running the
# plan. Stripe state and badge panels wait until a launch card is spent.
class AdminController < ApplicationController
  before_action :require_owner

  DAYS = 30

  def show
    @since = DAYS.days.ago
    load_signups
    load_cohort
    load_strangers
    load_recap_funnel
    load_weekly_email

    @posted_recaps  = posted_recaps.count
    @posted_by_user = posted_recaps.distinct.count(:user_id)
    @total_users    = User.counted.count
    @total_entries  = Entry.publicly_visible.where(user_id: counted_ids).count
    @pro_users      = User.counted.where(pro: true).count
    @subscribes     = Subscription.confirmed.where(confirmed_at: @since.., user_id: counted_ids).count
    @ref_visits     = Event.named("ref_visit").since(@since).group(:detail).count.sort_by { |_ref, count| -count }
    @shared_repos   = shared_repos
  end

  def test_email
    if current_user.email.blank?
      return redirect_to(admin_path, alert: "Your account has no email yet. Sign out and back in to capture it from GitHub.")
    end
    unless ENV["RESEND_API_KEY"].present?
      return redirect_to(admin_path, alert: "RESEND_API_KEY is not set, so delivery is still switched off.")
    end

    SystemMailer.test_email(current_user).deliver_now
    redirect_to admin_path, notice: "Sent to #{current_user.email}. Check inbox and spam."
  rescue StandardError => e
    redirect_to admin_path, alert: "Delivery failed: #{e.class} - #{e.message.truncate(120)}"
  end

  # Both weekly emails for my own week, to read in a real inbox before Friday.
  def test_weekly_email
    service = WeeklyEmails::TestService.new(user: current_user)
    if service.call
      redirect_to admin_path, notice: "Both weekly emails sent to #{current_user.email}, marked [Test]."
    else
      redirect_to admin_path, alert: service.errors.full_messages.to_sentence
    end
  rescue Net::SMTPError, Net::OpenTimeout, MailDeliveryGuard::Error => e
    Rails.error.report(e)
    redirect_to admin_path, alert: "Delivery failed: #{e.class} - #{e.message.truncate(120)}"
  end

  private

  # Test accounts (internal) are left out of every number on this page.
  def counted_ids
    User.counted.select(:id)
  end

  def load_signups
    @signups_by_ref = User.counted
                          .where(created_at: @since..)
                          .group(:signup_ref)
                          .count
                          .transform_keys { |ref| ref.presence || "unattributed" }
                          .sort_by { |_ref, count| -count }

    @signups_total  = @signups_by_ref.sum { |_ref, count| count }
    @signups_by_day = signups_by_day
  end

  def cohort
    User.counted.where(created_at: @since..)
  end

  def load_cohort
    @cohort     = cohort.count
    @activated  = cohort.joins(:entries).distinct.count
    @with_email = cohort.where.not(email: [ nil, "" ]).count
  end

  # Gate 1's north star, scored on people who are not me.
  def load_strangers
    strangers    = cohort.where.not(id: current_user.id)
    @strangers   = strangers.count
    @returned    = Event.returned_user_ids(strangers).size
    week_old     = strangers.where(created_at: ..7.days.ago)
    @week_old    = week_old.count
    @second_week = Event.second_week_user_ids(week_old).size
  end

  def load_recap_funnel
    recap_events  = Event.since(@since).where(user_id: counted_ids).where.not(user_id: current_user.id)
    @recap_funnel = %w[recap_opened recap_picked recap_copied recap_intent].map do |name|
      [ name, recap_events.named(name).distinct.count(:user_id) ]
    end
    @recap_quiet = recap_events.named("recap_quiet").distinct.count(:user_id)
    @card_funnel = %w[progress_card_downloaded progress_post_copied].map do |name|
      [ name, recap_events.named(name).distinct.count(:user_id) ]
    end
  end

  # F2's funnel. An email open cannot be seen without a tracking pixel, so the
  # first step after sending is the picker opened from the email's link.
  def load_weekly_email
    @weekly_mailed  = User.counted.where(weekly_email_sent_at: @since..).where.not(id: current_user.id).count
    @weekly_opened  = Event.since(@since).named("recap_from_email").where(user_id: counted_ids)
                           .where.not(user_id: current_user.id).distinct.count(:user_id)
    @digests_mailed = Subscription.where(digest_sent_at: @since.., user_id: counted_ids).where.not(user_id: current_user.id).count
  end

  def posted_recaps
    Entry.where(entry_type: :posted, occurred_at: @since.., user_id: counted_ids)
  end

  # The earliest honest audience signal: a repo with more than one builder on
  # it means someone was recruited by a teammate, not by the founder.
  def shared_repos
    Entry.where(source: :github, user_id: counted_ids)
         .where.not(repo_name: nil)
         .group(:repo_name)
         .having("COUNT(DISTINCT user_id) > 1")
         .count("DISTINCT user_id")
         .sort_by { |_repo, builders| -builders }
  end

  # Mirrors ProfileView.daily_counts so the two charts read the same way.
  def signups_by_day
    start   = DAYS.days.ago.to_date
    grouped = User.counted
                  .where(created_at: start.beginning_of_day..)
                  .group("DATE(created_at AT TIME ZONE 'UTC')")
                  .count

    (0...DAYS).each_with_object({}) do |offset, counts|
      date = start + offset
      counts[date.to_s] = grouped[date] || 0
    end
  end

  def require_owner
    head :not_found unless current_user&.owner?
  end
end
