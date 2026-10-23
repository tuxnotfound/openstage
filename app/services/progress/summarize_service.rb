module Progress
  # A card per project on the public page: what GitHub says it is, its
  # commits per week over the last 52 weeks, and its last commit. Reads the
  # same public, de-noised commits as the rest of the page.
  class SummarizeService < ApplicationService
    WEEKS = 52

    # weeks: commits per ISO week, oldest first, this week last.
    # private_repo: nil when the repo is no longer on the builder's list.
    Card = Data.define(:project, :description, :private_repo, :weeks, :last_commit) do
      delegate :repo, :name, :rank, to: :project

      def commits
        weeks.sum
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
        description, private_repo = repos[project.repo]
        Card.new(project: project, description: description.presence, private_repo: private_repo,
                 weeks: weekly.fetch(project.repo) { Array.new(WEEKS, 0) }, last_commit: last[project.repo]&.in_time_zone(zone)&.to_date)
      end
    end

    def github_repos
      user.github_repos.where(full_name: Array(projects).map(&:repo))
          .pluck(:full_name, :description, :private_repo).to_h { |name, description, private_repo| [ name, [ description, private_repo ] ] }
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
