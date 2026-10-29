module Progress
  # Counts a builder's numbers per project and day, in their zone, over the
  # days a chart needs: their public commits, as their pages count them, and
  # the visits to each project's website. Also the first day each project
  # counted each one, ever, since a chart starts where its numbers start.
  # Each project's first commit comes read with its rank (Projects), so a
  # page reads it once.
  class CountService < ApplicationService
    # commit_repos: the full names of the repos whose commits count;
    # visit_repos: the GithubRepos whose visits count; from: the first day
    # needed, nil for every day. reveal: a repo the builder hid, counted
    # anyway (Entry.on_page). first_commits: the time of each project's
    # first commit, ever (Projects#first_commits).
    attr_accessor :user, :reveal, :commit_repos, :visit_repos, :from, :first_commits
    # counts: a Progress::Counts.
    attr_reader :counts

    validates :user, presence: true

    private

    def execute
      @counts = Counts.new(days: { "commits" => commit_days, "visits" => visit_days },
                           firsts: { "commits" => commit_firsts, "visits" => visit_firsts })
    end

    def commit_days
      scope = from ? commits.where(occurred_at: from.in_time_zone(zone)..) : commits
      nested(scope.group(:repo_name, Arel.sql(LocalDay.of("entries.occurred_at", zone))).count)
    end

    def commit_firsts
      first_commits.slice(*Array(commit_repos)).transform_values { |time| time.in_time_zone(zone).to_date }
    end

    def visit_days
      scope = from ? visits.where(day: from..) : visits
      nested(scope.group(:github_repo_id, :day).sum(:visits)).transform_keys { |id| names.fetch(id) }
    end

    def visit_firsts
      visits.group(:github_repo_id).minimum(:day).transform_keys { |id| names.fetch(id) }
    end

    def commits
      user.entries.on_page(reveal: reveal).commits.where(repo_name: Array(commit_repos))
    end

    def visits
      SiteVisitDay.where(github_repo_id: names.keys)
    end

    def names
      @names ||= Array(visit_repos).to_h { |repo| [ repo.id, repo.full_name ] }
    end

    def zone
      user.zone
    end

    # {[project, day] => count} as {project => {day => count}}.
    def nested(pairs)
      pairs.each_with_object({}) { |((project, day), count), out| (out[project] ||= {})[day.to_date] = count }
    end
  end
end
