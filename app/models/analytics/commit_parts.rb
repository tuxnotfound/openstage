module Analytics
  # The Commits tab's own parts, for a window and the projects in view:
  # how many days had a commit (active), of the days from the window's
  # first, or the first commit's when later, to its last (days); each
  # project's last commit, ever (last_commit); when the builder commits, by
  # weekday and hour (CommitHours); and what shipped and was published,
  # newest first, the entries the chart marks (news).
  class CommitParts
    attr_reader :days, :active, :news

    # window: the Progress::Window the totals cover; counts: the tab's
    # Progress::Counts; rows: the Progress::Rows in view; last_commits: each
    # project's last commit, by repo (Progress::Projects#last_commits);
    # items: the Progress::TallyService::Items the chart marks, oldest first.
    def initialize(user:, window:, counts:, rows:, last_commits:, items:)
      @user = user
      @window = window
      @keys = rows.map(&:key)
      @last_commits = last_commits
      @news = items.reverse
      first = [ window.span&.first, counts.first_day("commits", @keys) ].compact.max
      @days = first ? [ (window.last - first).to_i + 1, 0 ].max : 0
      @active = @days.positive? ? counts.days_counted("commits", @keys, first..window.last) : 0
    end

    # The day of a project's last commit in the builder's zone; nil for none.
    def last_commit(key)
      @last_commits[key]&.in_time_zone(@user.zone)&.to_date
    end

    def hours
      @hours ||= CommitHours.new(@user, first: @window.span&.first, last: @window.last, repos: @keys).all
    end
  end
end
