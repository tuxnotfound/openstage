module Progress
  # Counts a builder's public work over one period of the progress section:
  # commits per project in each bucket, active days, what they shipped and
  # published, and the same counts over the same span of the period before.
  # With repos, only those projects' commits and the entries tagged with them
  # count; nothing is inferred from text. Days are in the zone of the
  # builder's last saved week card, else UTC. Rolling, the period is a Window
  # that ends today (the public page); otherwise a calendar Period (the cards).
  class TallyService < ApplicationService
    # A shipped or published entry on its day in the builder's zone.
    Item = Data.define(:entry, :date, :kind) do
      delegate :id, :title, :body, :repo_name, :pinned?, to: :entry

      def shipped?
        kind == :shipped
      end
    end
    # counts: commits by repo, the selected repos' only under a filter.
    Bucket = Data.define(:span, :counts, :total, :items)
    # all_commits counts every project's, for the selected one's share.
    Totals = Data.define(:shipped, :published, :commits, :all_commits, :active_days, :counts) do
      def projects
        counts.count { |repo, n| repo && n.positive? }
      end

      def share
        all_commits.zero? ? 0 : (100.0 * commits / all_commits).round
      end
    end

    # repos: the projects in view; none for all of them.
    attr_accessor :user, :range, :offset, :repos, :rolling
    attr_reader :zone, :period, :projects, :items, :buckets, :totals, :previous_totals, :first_active_day
    # The period's first day with a commit in view; nil without one.
    attr_reader :first_commit_day
    # The period's entries with no project that the builder has not marked as
    # having none, newest first; whatever the filter, so they can be tagged.
    attr_reader :untagged
    # Each day's commits by repo, every project's, to order the tag buttons.
    attr_reader :day_counts

    validates :user, presence: true

    private

    def execute
      @zone = ActiveSupport::TimeZone[WeekCard.last_time_zone_for(user).to_s] || ActiveSupport::TimeZone["UTC"]
      @projects = Projects.new(public_entries)
      @period = period_for(Time.current.in_time_zone(zone).to_date, first_day_of(public_entries))
      @items = items_on(period.first..period.last_day)
      @buckets = period.buckets.map { |bucket| tally_bucket(bucket) }
      @totals = totals_on(period.first..period.last_day)
      @previous_totals = totals_on(period.comparison) if period.comparison
      @first_commit_day = selected_commits_on(period.first..period.last_day).map(&:first).min
      @first_active_day = [ first_commit_day, *items.map(&:date) ].compact.min
      @untagged = untagged_on(period.first..period.last_day)
      @day_counts = window_commits.group_by(&:first).transform_values { |commits| tally(commits) }
    end

    def period_for(today, first_activity)
      return Window.new(range: range, today: today, first_activity: first_activity) if rolling

      Period.new(range: range, offset: offset, today: today, first_activity: first_activity)
    end

    def selected?
      Array(repos).any?
    end

    def shows?(repo)
      !selected? || repos.include?(repo)
    end

    def public_entries
      @public_entries ||= user.entries.publicly_visible.without_tooling_noise
    end

    def first_day_of(entries)
      first = entries.commits.or(entries.highlights).minimum(:occurred_at)
      first&.in_time_zone(zone)&.to_date
    end

    def tally_bucket(bucket)
      days = bucket.first..bucket.last
      counts = tally(selected_commits_on(days))
      Bucket.new(span: bucket, counts: counts, total: counts.values.sum, items: items.select { |item| days.cover?(item.date) })
    end

    def totals_on(days)
      selected = selected_commits_on(days)
      shown = items_on(days)
      Totals.new(shipped: shown.count(&:shipped?), published: shown.count { |item| !item.shipped? },
                 commits: selected.size, all_commits: commits_on(days).size,
                 active_days: (selected.map(&:first) + shown.map(&:date)).uniq.size, counts: tally(selected))
    end

    def tally(commits)
      commits.group_by(&:last).transform_values(&:size)
    end

    def selected_commits_on(days)
      commits_on(days).select { |_date, commit_repo| shows?(commit_repo) }
    end

    def commits_on(days)
      window_commits.select { |date, _repo| days.cover?(date) }
    end

    def items_on(days)
      window_items.select { |item| days.cover?(item.date) && shows?(item.repo_name) }
    end

    def untagged_on(days)
      window_items.select { |item| days.cover?(item.date) && item.repo_name.nil? && !item.entry.no_project? }
                  .sort_by { |item| [ -item.date.jd, -item.id ] }
    end

    # [date, repo] for every public commit from the comparison's start to today.
    def window_commits
      @window_commits ||= public_entries.commits.where(occurred_at: window).pluck(:occurred_at, :repo_name)
                                        .map { |at, commit_repo| [ at.in_time_zone(zone).to_date, commit_repo ] }
    end

    def window_items
      @window_items ||= public_entries.highlights.where(occurred_at: window).order(:occurred_at, :id).map do |entry|
        Item.new(entry: entry, date: entry.occurred_at.in_time_zone(zone).to_date,
                 kind: Entry::SHIPPED_TYPES.include?(entry.entry_type) ? :shipped : :published)
      end
    end

    def window
      from = [ period.first, period.comparison&.first ].compact.min
      from.in_time_zone(zone)...(period.last_day + 1).in_time_zone(zone)
    end
  end
end
