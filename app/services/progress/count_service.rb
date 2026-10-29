module Progress
  # Counts a builder's numbers per project and day, in their zone, over the
  # days a chart needs: their public commits, as their pages count them, and
  # the visits to each project's website. Also the first day each project
  # counted each one, ever, since a chart starts where its numbers start.
  # The commits come read with the page's section (TallyService#commit_days,
  # Projects#first_commits), so a page reads them once.
  class CountService < ApplicationService
    # commit_repos: the full names of the repos whose commits count;
    # visit_repos: the GithubRepos whose visits count; from: the first day
    # needed, nil for every day. commit_days: the builder's commits by day
    # and project, {[date, repo] => count}, from that day on at least;
    # first_commits: the time of each project's first commit, ever.
    attr_accessor :user, :commit_repos, :visit_repos, :from, :commit_days, :first_commits
    # counts: a Progress::Counts.
    attr_reader :counts

    validates :user, presence: true

    private

    def execute
      @counts = Counts.new(days: { "commits" => counted_commits, "visits" => visit_days },
                           firsts: { "commits" => commit_firsts, "visits" => visit_firsts })
    end

    # {repo => {date => count}} for the repos whose commits count.
    def counted_commits
      repos = Array(commit_repos).to_set
      commit_days.each_with_object({}) do |((date, repo), count), out|
        (out[repo] ||= {})[date] = count if repos.include?(repo) && (from.nil? || date >= from)
      end
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
