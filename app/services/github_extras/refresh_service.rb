module GithubExtras
  # What the week card and the project pages read from GitHub beyond commits:
  # star counts, each repo's words and picture, releases, merged pull requests,
  # deploys, and the lines each commit changed. Runs after every successful sync.
  class RefreshService < ApplicationService
    attr_accessor :user

    validates :user, presence: true

    private

    def execute
      tokens = Tokens.new(user)
      [
        GithubRepos::SnapshotStarsService.new(user: user),
        GithubRepos::DescribeService.new(user: user, tokens: tokens),
        GithubReleases::ImportService.new(user: user, tokens: tokens),
        GithubPulls::ImportService.new(user: user, tokens: tokens),
        GithubDeployments::ImportService.new(user: user, tokens: tokens),
        GithubCommits::FetchStatsService.new(user: user, tokens: tokens)
      ].each do |service|
        service.call
        absorb_errors(service)
      end
    end
  end
end
