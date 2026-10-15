module GithubCommits
  # Puts the builder's commits on a repo's other branches on their page, each
  # tagged with its branch (FUTURE_FEATURES item 7). It reads only what a branch
  # has that the default branch lacks, and only for branches whose head moved
  # since the last read, so an idle branch costs no call.
  class ImportBranchesService < ApplicationService
    # Bot branches hold bot commits, which RecordService drops anyway.
    BOT_BRANCH = %r{\A(dependabot|renovate)/}

    # token: reads the repo, as the sync's own client does.
    attr_accessor :user, :repo, :token
    attr_reader :added

    validates :user, :repo, :token, presence: true

    private

    def execute
      @added = 0
      branches = GithubGateway.branches(repo.full_name, token: token).reject { |branch| skipped?(branch) }
      branches.each { |branch| import(branch) unless repo.branch_heads[branch.name] == branch.sha }
      repo.update!(branch_heads: branches.to_h { |branch| [ branch.name, branch.sha ] })
    end

    def skipped?(branch)
      branch.name == repo.default_branch || branch.name.match?(BOT_BRANCH)
    end

    # Branch work older than a repo's first sync window stays off the page, as
    # the default branch's does.
    def import(branch)
      since = GithubSyncJob::INITIAL_SYNC_WINDOW.ago
      GithubGateway.commits_ahead(repo.full_name, base: repo.default_branch, head: branch.sha, token: token).each do |commit|
        next unless commit.authored_at && commit.authored_at >= since

        record = RecordService.new(user: user, repo: repo, commit: commit, branch: branch.name, token: token)
        @added += 1 if record.tap(&:call!).added
      end
    end
  end
end
