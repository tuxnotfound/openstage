module GithubCommits
  # Puts one commit GitHub listed on the builder's page, or finds it already
  # there. A commit only on a branch other than the default carries that branch
  # until it reaches the default branch, whichever way it gets there: merged as
  # it was (same SHA), rebased (new SHA, same author date and title) or squashed
  # into one commit, whose pull request names the commits it holds.
  class RecordService < ApplicationService
    # GitHub titles a squash merge after its pull request: "Add search (#12)".
    SQUASH_TITLE = /\(#\d+\)\z/

    # commit: a GithubGateway::Commit. branch: the branch it was read on, nil
    # for the default branch. token: reads the repo's pull requests.
    attr_accessor :user, :repo, :commit, :branch, :token
    attr_reader :added

    validates :user, :repo, :commit, presence: true

    private

    def execute
      @added = false
      return unless authored?

      entry = commits.find_by(external_id: commit.sha)
      return reach_default_branch(entry) if entry
      return if DismissedCommit.exists?(user_id: user.id, sha: commit.sha)

      entry = moved_entry
      return move(entry) if entry
      return if squash_of_branch_commits?

      @added = create_entry
    end

    # GitHub leaves a commit's author empty when its email is not tied to a
    # verified account, so the builder's noreply address counts too.
    def authored?
      username = user.github_username.to_s.downcase
      return false if username.empty?
      return true if commit.author_login.to_s.downcase == username

      commit.author_email.to_s.downcase.match?(/\A(?:\d+\+)?#{Regexp.escape(username)}@users\.noreply\.github\.com\z/)
    end

    def commits
      user.entries.where(source: :github)
    end

    # Merged with a merge commit or fast-forwarded: the same SHA, now on the
    # default branch.
    def reach_default_branch(entry)
      entry.update!(branch: nil) if branch.nil? && entry.branch.present?
    end

    # A rebase, on the branch or by GitHub's "Rebase and merge", gives the commit
    # a new SHA and keeps its author date and title.
    def moved_entry
      branch_commits.find_by(occurred_at: commit.authored_at, title: title)
    end

    def move(entry)
      entry.update!(external_id: commit.sha, url: url, branch: branch)
    end

    # The squash commit is left out when its pull request's commits are already
    # on the page: they carry the work, and they reach the default branch.
    def squash_of_branch_commits?
      return false unless branch.nil? && title.match?(SQUASH_TITLE) && branch_commits.exists?

      shas = GithubGateway.merged_pull_numbers(repo.full_name, commit.sha, token: token).flat_map do |number|
        GithubGateway.pull_commit_shas(repo.full_name, number, token: token)
      end
      branch_commits.where(external_id: shas).update_all(branch: nil, updated_at: Time.current).positive?
    rescue ApplicationGateway::Unauthorized, ApplicationGateway::NotFound
      # The token cannot read pull requests (a GitHub App permission not yet
      # accepted), so the squash commit goes on the page as it did before.
      false
    end

    def branch_commits
      commits.where(repo_name: repo.full_name).where.not(branch: nil)
    end

    def create_entry
      commits.create!(entry_type: :shipped, external_id: commit.sha, title: title, occurred_at: commit.authored_at,
                      url: url, repo_name: repo.full_name, branch: branch)
      true
    rescue ActiveRecord::RecordNotUnique
      # Another sync of the same builder recorded it first.
      false
    end

    def title
      @title ||= commit.message.to_s.split("\n").first.to_s.truncate(200).presence || commit.sha.first(7)
    end

    # Never expose commit links for private repositories.
    def url
      repo.private_repo? ? nil : commit.html_url
    end
  end
end
