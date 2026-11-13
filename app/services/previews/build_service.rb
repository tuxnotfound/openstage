module Previews
  # The stage a GitHub user would get, built from their public work before
  # they sign in (Preview). GitHub is read once an hour per login, and the
  # preview is kept in the cache alone, never in the database. A GitHub
  # failure raises (GithubProfileGateway); a login GitHub does not know is
  # the visitor's mistake, so it is an error here.
  class BuildService < ApplicationService
    # GitHub's rule for a login: letters, digits and single hyphens, never
    # first or last, 39 at most.
    LOGIN = /\A[a-z\d](?:[a-z\d]|-(?=[a-z\d])){0,38}\z/i
    KEPT_FOR = 1.hour
    # Bumped when Preview changes shape, so a cached one from before a deploy is never read.
    CACHE_VERSION = 2
    # The projects whose latest commits it reads, and how many from each.
    RECENT_REPOS = 4
    RECENT_PER_REPO = 6
    # Public repos a preview with no commits shows instead.
    QUIET_REPOS = 6

    attr_accessor :login, :today
    attr_reader :preview

    validates :login, format: { with: LOGIN, message: "is not a GitHub username" }
    validates :today, presence: true

    private

    def execute
      @preview = Rails.cache.fetch([ "preview", CACHE_VERSION, login.downcase, today.iso8601 ], expires_in: KEPT_FOR) { build }
    rescue GithubProfileGateway::NotFound
      errors.add(:login, :not_found, message: "is not on GitHub")
    end

    def build
      profile = GithubProfileGateway.profile(login, from: Preview.first_day(today), to: today)
      preview = Preview.new(profile: profile, latest: latest(profile), today: today)
      return preview unless preview.empty?

      Preview.new(profile: profile, latest: preview.latest, today: today, quiet_repos: quiet_repos)
    end

    # With no commits in the 12 months, the repos that would join the stage
    # with their next commit: one more call, for quiet accounts alone.
    def quiet_repos
      GithubProfileGateway.recent_repos(login, count: QUIET_REPOS)
    end

    # The projects worked on last, as Recent commits shows them.
    def latest(profile)
      repos = profile.repos.select { |repo| repo.days.any? }.max_by(RECENT_REPOS) { |repo| repo.days.keys.max }
      return [] if repos.empty?

      GithubProfileGateway.commits(profile.id, repos.map(&:full_name), per_repo: RECENT_PER_REPO)
    end
  end
end
