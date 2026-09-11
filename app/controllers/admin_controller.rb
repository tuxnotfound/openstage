# Four numbers, deliberately. The gates in REBIRTH_PLAN.md are scored off this
# page, and anything beyond what a gate needs is a distraction from running the
# plan. Stripe state and badge panels wait until a launch card is spent.
class AdminController < ApplicationController
  before_action :require_owner

  DAYS = 30

  def show
    @since = DAYS.days.ago

    @signups_by_ref = User.active
                          .where(created_at: @since..)
                          .group(:signup_ref)
                          .count
                          .transform_keys { |ref| ref.presence || "unattributed" }
                          .sort_by { |_ref, count| -count }

    @signups_total  = @signups_by_ref.sum { |_ref, count| count }
    @signups_by_day = signups_by_day

    cohort      = User.active.where(created_at: @since..)
    @cohort     = cohort.count
    @activated  = cohort.joins(:entries).distinct.count
    @with_email = cohort.where.not(email: [ nil, "" ]).count

    @posted_recaps = Entry.where(entry_type: :posted, occurred_at: @since..).count
    @posted_by_user = Entry.where(entry_type: :posted, occurred_at: @since..)
                           .joins(:user).distinct.count(:user_id)

    @total_users    = User.active.count
    @total_entries  = Entry.publicly_visible.count
    @pro_users      = User.active.where(pro: true).count
  end

  private

  # Mirrors ProfileView.daily_counts so the two charts read the same way.
  def signups_by_day
    start   = DAYS.days.ago.to_date
    grouped = User.active
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
