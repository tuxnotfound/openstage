module Progress
  # Counts a builder's public work over one period of the progress section:
  # commits per project in each bucket, active days, what they shipped and
  # published, and the same counts over the same span of the period before.
  # With repos, only those projects' commits and the entries tagged with them
  # count; nothing is inferred from text. Days are in the builder's zone
  # (User#zone), else UTC. Rolling, the period is a Window that ends today
  # (the public page); otherwise a calendar Period (the weekly emails). A
  # page's chart counts more commits than the period's; asked to (counting),
  # the tally reads those too, so the page reads its commits once.
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

    # What a page's chart counts besides the period: every commit of these
    # projects (of every one for none) from a day on (on every day for none).
    Counting = Data.define(:from, :repos)

    # repos: the projects in view; none for all of them. reveal: a repo the builder hid, shown anyway (Entry.on_page).
    # counting: what the page's chart also counts (Counting); none for the period alone.
    # ranked: the caller ranks the projects too (Projects#all), as a section does.
    attr_accessor :user, :range, :offset, :repos, :rolling, :reveal, :counting, :ranked
    attr_reader :zone, :period, :projects, :items, :buckets, :totals, :previous_totals, :first_active_day
    # The period's entries with no project that the builder has not marked as
    # having none, newest first; whatever the filter, so they can be tagged.
    attr_reader :untagged
    # Each day's commits by repo, every project's, to order the tag buttons.
    attr_reader :day_counts
    # Each day's commits by project, {[date, repo] => count}: every public
    # commit over the period and its comparison, and what counting adds.
    attr_reader :commit_days

    validates :user, presence: true

    private

    def execute
      @zone = user.zone
      @projects = Projects.new(public_entries)
      @period = period_for(Time.current.in_time_zone(zone).to_date, first_day_of(projects))
      @commit_days = commits_by_day
      @items = items_on(period.first..period.last_day)
      @buckets = period.buckets.map { |bucket| tally_bucket(bucket) }
      @totals = totals_on(period.first..period.last_day)
      @previous_totals = totals_on(period.comparison) if period.comparison
      first_commit_day = selected_commits_on(period.first..period.last_day).keys.map(&:first).min
      @first_active_day = [ first_commit_day, *items.map(&:date) ].compact.min
      @untagged = untagged_on(period.first..period.last_day)
      @day_counts = window_commits.group_by { |(date, _repo), _count| date }.transform_values { |commits| tally(commits) }
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
      @public_entries ||= user.entries.on_page(reveal: reveal)
    end

    # The first commit or entry in view: of the projects picked, when picked.
    # A page leaves out the commits of projects that hide them, so its window
    # never starts at one; the emails, which still count them, keep them.
    def first_day_of(projects)
      first = ranked ? first_ranked(projects) : first_in_view
      first&.in_time_zone(zone)&.to_date
    end

    # Taken from the reads that rank the projects, which the caller makes anyway.
    def first_ranked(projects)
      firsts = [ projects.first_commits(shown: rolling), projects.first_highlights ]
      firsts.flat_map { |by_repo| selected? ? by_repo.values_at(*repos) : by_repo.values }.compact.min
    end

    # One MIN, by the index on a project's entries when picked: a tally whose
    # projects nobody ranks (the weekly emails' quiet check) would otherwise
    # read the builder's whole history for every project.
    def first_in_view
      commits = rolling ? public_entries.commits.without_hidden_commits : public_entries.commits
      scope = commits.or(public_entries.highlights)
      scope = scope.where(repo_name: repos) if selected?
      scope.minimum(:occurred_at)
    end

    # {[date, repo] => count} for every public commit the tally and the
    # page's chart count, counted by day in SQL: a row per day and project,
    # however many commits there are.
    def commits_by_day
      commit_scope.group(Arel.sql(LocalDay.of("entries.occurred_at", zone)), :repo_name).count
                  .transform_keys { |(date, commit_repo)| [ date.to_date, commit_repo ] }
    end

    # The window's commits, and with counting the ones the chart also counts.
    def commit_scope
      commits = public_entries.commits
      scope = commits.where(occurred_at: window)
      return scope unless counting

      counted = counting.from ? commits.where(occurred_at: counting.from.in_time_zone(zone)..) : commits
      scope.or(counting.repos ? counted.where(repo_name: counting.repos) : counted)
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
                 commits: selected.values.sum, all_commits: commits_on(days).values.sum,
                 active_days: (selected.keys.map(&:first) + shown.map(&:date)).uniq.size, counts: tally(selected))
    end

    # Commits by repo, from {[date, repo] => count} pairs.
    def tally(commits)
      commits.each_with_object({}) { |((_date, repo), count), counts| counts[repo] = counts.fetch(repo, 0) + count }
    end

    def selected_commits_on(days)
      commits_on(days).select { |(_date, commit_repo), _count| shows?(commit_repo) }
    end

    def commits_on(days)
      window_commits.select { |(date, _repo), _count| days.cover?(date) }
    end

    def items_on(days)
      window_items.select { |item| days.cover?(item.date) && shows?(item.repo_name) }
    end

    def untagged_on(days)
      window_items.select { |item| days.cover?(item.date) && item.repo_name.nil? && !item.entry.no_project? }
                  .sort_by { |item| [ -item.date.jd, -item.id ] }
    end

    # {[date, repo] => count} for every public commit from the comparison's
    # start to today.
    def window_commits
      @window_commits ||= commit_days.select { |(date, _repo), _count| window_days.cover?(date) }
    end

    def window_items
      @window_items ||= public_entries.highlights.where(occurred_at: window).order(:occurred_at, :id).map do |entry|
        Item.new(entry: entry, date: entry.occurred_at.in_time_zone(zone).to_date,
                 kind: Entry::SHIPPED_TYPES.include?(entry.entry_type) ? :shipped : :published)
      end
    end

    def window
      window_days.first.in_time_zone(zone)...(window_days.last + 1).in_time_zone(zone)
    end

    # The period's days and its comparison's.
    def window_days
      [ period.first, period.comparison&.first ].compact.min..period.last_day
    end
  end
end
