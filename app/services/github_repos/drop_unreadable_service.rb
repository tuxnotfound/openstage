module GithubRepos
  # Removes a builder's private repos that no GitHub listing returned, so
  # Openstage cannot read them any more: taken out of the GitHub App, the App
  # uninstalled, or the repo deleted. GitHub's list wins: their commits come off
  # the profile and the rows leave Settings. Picked again on GitHub, a repo comes
  # back excluded, and including it shows its commits again.
  class DropUnreadableService < ApplicationService
    attr_accessor :user, :listed_ids
    attr_reader :dropped

    validates :user, presence: true
    validate :listed_ids_given

    private

    def execute
      unreadable = user.github_repos.where(private_repo: true).where.not(github_repo_id: listed_ids)
      @dropped = unreadable.pluck(:full_name)
      return if dropped.empty?

      transaction do
        user.entries.where(source: :github, repo_name: dropped).update_all(hidden: true, url: nil)
        unreadable.delete_all
      end
    end

    # An empty list is valid (nothing readable); a missing one would drop
    # everything by mistake.
    def listed_ids_given
      errors.add(:listed_ids, "are missing") if listed_ids.nil?
    end
  end
end
