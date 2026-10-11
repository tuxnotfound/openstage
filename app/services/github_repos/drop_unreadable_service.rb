module GithubRepos
  # Removes a builder's private repos that no GitHub listing returned, so
  # Openstage cannot read them any more: taken out of the GitHub App, the App
  # uninstalled, or the repo deleted. GitHub's list wins: their commits come off
  # the profile and the rows leave Settings. Picked again on GitHub, a repo comes
  # back excluded, and including it shows its commits again.
  class DropUnreadableService < ApplicationService
    # listed_at is when the listing began. A row recorded after it, by a Settings
    # check or a webhook while a long sync ran, is missing from the listing only
    # because it is newer, so it is never dropped.
    attr_accessor :user, :listed_ids, :listed_at
    attr_reader :dropped

    validates :user, presence: true
    validate :listing_given

    private

    def execute
      rows = user.github_repos.where(private_repo: true, created_at: ...listed_at)
                 .where.not(github_repo_id: listed_ids).pluck(:id, :full_name)
      @dropped = rows.map(&:last)
      return if rows.empty?

      transaction do
        user.entries.where(source: :github, repo_name: dropped).update_all(hidden: true, url: nil)
        GithubRepo.where(id: rows.map(&:first)).delete_all
      end
    end

    # An empty list is valid (nothing readable); a missing one would drop
    # everything by mistake.
    def listing_given
      errors.add(:listed_ids, "are missing") if listed_ids.nil?
      errors.add(:listed_at, "is missing") if listed_at.nil?
    end
  end
end
