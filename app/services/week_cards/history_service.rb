module WeekCards
  # The builder's public work before a week card's week, for the facts that
  # set the week against what came before: the commits before it, the best
  # week before it, the quiet weeks right before it, the run of active days at
  # its end, and when the earlier commits landed. Days and hours are the
  # card's time zone's. One grouped, bounded query each, so a long history
  # costs no more than a short one.
  class HistoryService < ApplicationService
    # best_week is nil before the builder's first commit. since is the day the
    # dust starts: building_since, else the first commit. dust maps
    # [ISO weekday, hour] to the commits since then.
    History = Data.define(:commits_before, :best_week, :quiet_weeks, :streak, :since, :dust)
    # How far back a run of active days is followed.
    STREAK_DAYS = 366

    attr_accessor :week_card
    attr_reader :history

    validates :week_card, presence: true

    private

    def execute
      since = week_card.user.building_since || earlier_commits.minimum(:occurred_at)&.in_time_zone(week_card.zone)&.to_date
      @history = History.new(commits_before: earlier_commits.count, best_week: best_week, quiet_weeks: quiet_weeks,
                             streak: streak, since: since, dust: dust(since))
    end

    def week_begins
      week_card.time_range.begin
    end

    # Commits and logs, as the card counts them.
    def activity
      week_card.user.entries.publicly_visible.without_tooling_noise
    end

    def earlier_commits
      activity.where(source: :github, entry_type: :shipped, occurred_at: ...week_begins)
    end

    def best_week
      earlier_commits.group(local("date_trunc('week', %s)")).count.values.max
    end

    # Weeks with no commits and nothing logged between this one and the last
    # active week. Before the builder's first entry, weeks are not quiet.
    def quiet_weeks
      last = activity.where(occurred_at: ...week_begins).maximum(:occurred_at)
      return 0 unless last

      ((week_card.week_start - last.in_time_zone(week_card.zone).to_date.beginning_of_week).to_i / 7) - 1
    end

    # Days in a row with work, up to the week's last day. In the current week
    # it runs to today, or to yesterday while today has nothing yet.
    def streak
      today = Time.current.in_time_zone(week_card.zone).to_date
      last = [ week_card.days.last, today ].min
      active = active_dates(last).to_set
      last -= 1 if last == today && !active.include?(last)
      (0..STREAK_DAYS).take_while { |back| active.include?(last - back) }.size
    end

    def active_dates(last)
      ends = midnight(last + 1)
      activity.where(occurred_at: (ends - (STREAK_DAYS + 1).days)...ends).distinct.pluck(local("(%s)::date"))
    end

    def dust(since)
      return {} unless since

      earlier_commits.where(occurred_at: midnight(since)..)
                     .group(local("extract(isodow from %s)::int"), local("extract(hour from %s)::int")).count
    end

    def midnight(date)
      week_card.zone.local(date.year, date.month, date.day)
    end

    # A SQL expression over the entry's time in the card's zone.
    def local(expression)
      zone = Entry.connection.quote(week_card.zone.tzinfo.identifier)
      Arel.sql(format(expression, "((entries.occurred_at AT TIME ZONE 'UTC') AT TIME ZONE #{zone})"))
    end
  end
end
