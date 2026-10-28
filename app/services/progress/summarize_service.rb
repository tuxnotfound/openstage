module Progress
  # A card per project on the public page: what it is (the builder's words, else
  # GitHub's), its website and picture, its commits per week over the last 52
  # weeks, and its last commit. Reads the same public, de-noised commits as the
  # rest of the page.
  class SummarizeService < ApplicationService
    WEEKS = 52

    # weeks: commits per ISO week, oldest first, this week last, from the
    # project's first commit when that came within the 52 weeks. github_repo:
    # nil when the repo is no longer on the builder's list.
    Card = Data.define(:project, :github_repo, :weeks, :last_commit) do
      delegate :repo, :name, :rank, to: :project
      delegate :website, :picture, :live?, :archived?, to: :github_repo, allow_nil: true

      def commits
        weeks.sum
      end

      def description
        github_repo&.project_description
      end

      def private_repo
        github_repo&.private_repo?
      end

      # Whether visitors see its commits: its builder may hide them, and
      # then its card shows no count, no weekly chart and no last commit.
      def commits_shown?
        github_repo.nil? || github_repo.public_number?("commits")
      end
    end

    # projects: Progress::Projects#all, in rank order. reveal: a repo the builder hid, shown anyway (Entry.on_page).
    attr_accessor :user, :projects, :zone, :reveal
    attr_reader :cards

    validates :user, :zone, presence: true

    private

    def execute
      repos = github_repos
      bounds = commits.group(:repo_name).pluck(:repo_name, Arel.sql("MIN(entries.occurred_at)"), Arel.sql("MAX(entries.occurred_at)"))
                      .to_h { |repo, first, last| [ repo, [ local(first), local(last) ] ] }
      weekly = weekly_counts
      @cards = Array(projects).map do |project|
        first, last = bounds[project.repo]
        Card.new(project: project, github_repo: repos[project.repo], weeks: since(first, weekly.fetch(project.repo) { Array.new(WEEKS, 0) }),
                 last_commit: last)
      end
    end

    def github_repos
      user.github_repos.by_full_name(Array(projects).map(&:repo))
    end

    def commits
      user.entries.on_page(reveal: reveal).commits
    end

    # Commits per week, counted by day in SQL: a row per day and project.
    def weekly_counts
      counts = Hash.new { |hash, repo| hash[repo] = Array.new(WEEKS, 0) }
      day = Arel.sql(LocalDay.of("entries.occurred_at", zone))
      commits.where(occurred_at: first_monday.in_time_zone(zone)..).group(:repo_name, day).count.each do |(repo, date), count|
        week = (date.to_date - first_monday).to_i / 7
        counts[repo][week] += count if week < WEEKS
      end
      counts
    end

    # A project begun inside the 52 weeks starts its chart at its first week.
    def since(first_commit, weeks)
      return weeks unless first_commit && first_commit > first_monday

      weeks.drop((first_commit - first_monday).to_i / 7)
    end

    def local(time)
      time&.in_time_zone(zone)&.to_date
    end

    def first_monday
      @first_monday ||= begin
        today = Time.current.in_time_zone(zone).to_date
        today - (today.cwday - 1) - ((WEEKS - 1) * 7)
      end
    end
  end
end
