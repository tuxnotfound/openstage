module GithubRepos
  # Records a repo as GitHub listed it for a builder: creates or updates its row,
  # applies the consent defaults, and keeps the repo's commits in step with it.
  # The sync, the Settings check and the webhooks share it, so one place decides
  # what a newly seen repo starts as.
  class RecordService < ApplicationService
    # listing: anything with id, name, full_name, description, html_url,
    # default_branch and private, as Octokit and GithubAppGateway::Repo both have.
    attr_accessor :user, :listing
    attr_reader :repo

    validates :user, presence: true
    validate :listing_given

    private

    def execute
      @repo = GithubRepo.find_or_initialize_by(user: user, github_repo_id: listing.id)
      reset_watermark_on_branch_rename
      repo.assign_attributes(
        name: listing.name,
        full_name: listing.full_name,
        description: listing.description,
        url: listing.html_url,
        default_branch: default_branch,
        private_repo: !!listing.private
      )
      apply_consent_defaults
      save_with_commits
    rescue ActiveRecord::RecordNotUnique
      use_row_recorded_meanwhile
    end

    # A default-branch rename invalidates last_synced_at: the watermark was set
    # against the old branch, and commits on the new branch may predate it, so
    # a normal sync would miss them. Reset to force the initial sync window.
    def reset_watermark_on_branch_rename
      repo.last_synced_at = nil if repo.persisted? && repo.default_branch != default_branch
    end

    def default_branch
      listing.default_branch || "main"
    end

    # Private repos are opt-out by default: nobody signs up expecting their
    # private commit messages to be published. The false -> true transition is
    # the moment we learn a repo is private; the old included:true default was
    # never a consent, so re-default once. A choice the user made by hand
    # (included_chosen) is a consent and is never overridden.
    def apply_consent_defaults
      newly_known_private = repo.private_repo? && (repo.new_record? || repo.private_repo_changed?)
      repo.included = false if newly_known_private && !repo.included_chosen?
      repo.included = true if repo.new_record? && !repo.private_repo?
    end

    # Commits are tied to their repo by name. A rename carries them along, so a
    # later exclude or drop still finds them, and a repo just excluded for going
    # private takes its commits off the profile now, not at the next sync.
    def save_with_commits
      renamed_from = repo.full_name_in_database if repo.persisted? && repo.full_name_changed?
      excluded_now = repo.persisted? && repo.included_changed?(from: true, to: false)
      transaction do
        if repo.save
          commits.where(repo_name: renamed_from).update_all(repo_name: repo.full_name) if renamed_from
          commits.where(repo_name: repo.full_name).update_all(hidden: true, url: nil) if excluded_now
        elsif repo.errors.of_kind?(:github_repo_id, :taken)
          use_row_recorded_meanwhile
        else
          absorb_errors(repo)
        end
      end
    end

    def commits
      user.entries.where(source: :github)
    end

    # The sync, a Settings check or a webhook recorded the same new repo at the
    # same moment, from the same listing, and its insert won.
    def use_row_recorded_meanwhile
      @repo = GithubRepo.find_by!(user: user, github_repo_id: listing.id)
    end

    def listing_given
      errors.add(:listing, "is missing") if listing.nil?
    end
  end
end
