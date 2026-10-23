module Progress
  # A card per project on the public page: what it is (the builder's words, else
  # GitHub's), its website and picture, its commits per week over the last 52
  # weeks, and its last commit. Reads the same public, de-noised commits as the
  # rest of the page.
  class SummarizeService < ApplicationService
    WEEKS = 52

    # weeks: commits per ISO week, oldest first, this week last. github_repo:
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
    end

    # projects: Progress::Projects#all, in rank order.
    attr_accessor :user, :projects, :zone
    attr_reader :cards

    validates :user, :zone, presence: true

    private

    def execute
      repos = github_repos
      last = commits.group(:repo_name).maximum(:occurred_at)
      weekly = weekly_counts
      @cards = Array(projects).map do |project|
        Card.new(project: project, github_repo: repos[project.repo], weeks: weekly.fetch(project.repo) { Array.new(WEEKS, 0) },
                 last_commit: last[project.repo]&.in_time_zone(zone)&.to_date)
      end
    end

    def github_repos
      user.github_repos.where(full_name: Array(projects).map(&:repo)).index_by(&:full_name)
    end

    def commits
      user.entries.publicly_visible.without_tooling_noise.commits
    end

    def weekly_counts
      counts = Hash.new { |hash, repo| hash[repo] = Array.new(WEEKS, 0) }
      commits.where(occurred_at: first_monday.in_time_zone(zone)..).pluck(:occurred_at, :repo_name).each do |at, repo|
        week = (at.in_time_zone(zone).to_date - first_monday).to_i / 7
        counts[repo][week] += 1 if week < WEEKS
      end
      counts
    end

    def first_monday
      @first_monday ||= begin
        today = Time.current.in_time_zone(zone).to_date
        today - (today.cwday - 1) - ((WEEKS - 1) * 7)
      end
    end
  end
end
