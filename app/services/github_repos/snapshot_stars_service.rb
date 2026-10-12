module GithubRepos
  # Writes down today's star count for each repo a builder includes, so a week
  # card can tell the stars a week brought. The count itself arrives with the
  # repo listing on every sync; the last one of the day stands.
  class SnapshotStarsService < ApplicationService
    attr_accessor :user

    validates :user, presence: true

    private

    def execute
      rows = user.github_repos.included_repos.where.not(stars_count: nil).pluck(:id, :stars_count).map do |repo_id, stars|
        { github_repo_id: repo_id, recorded_on: Date.current, stars: stars }
      end
      GithubRepoStarCount.upsert_all(rows, unique_by: %i[github_repo_id recorded_on]) if rows.any?
    end
  end
end
