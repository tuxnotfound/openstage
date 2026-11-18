module Analytics
  # When a builder commits: their commits over some days, for some projects,
  # by weekday, Monday first, and hour, in their zone, as the Commits tab
  # counts them (CountService), in one grouped query.
  class CommitHours
    # first: the first day, nil for every day up to last; repos: the
    # projects' full names.
    def initialize(user, first:, last:, repos:)
      @user = user
      @first = first
      @last = last
      @repos = repos
    end

    # {[weekday, 0 for Monday, hour] => commits}, the hours with none left out.
    def all
      return {} if @repos.empty?

      local = "((entries.occurred_at AT TIME ZONE 'UTC') AT TIME ZONE #{ActiveRecord::Base.connection.quote(zone.tzinfo.identifier)})"
      @user.entries.publicly_counted.without_tooling_noise.commits.where(repo_name: @repos, occurred_at: times)
           .group(Arel.sql("EXTRACT(ISODOW FROM #{local})::int - 1"), Arel.sql("EXTRACT(HOUR FROM #{local})::int")).count
    end

    private

    def zone
      @user.zone
    end

    def times
      @first&.in_time_zone(zone)...(@last + 1).in_time_zone(zone)
    end
  end
end
