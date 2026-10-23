module GithubRepos
  # Reads what a project's page says when the repo's GitHub description is
  # empty: its README's first line and its custom social preview, for each
  # included repo with work on Openstage, at most once a day.
  class DescribeService < ApplicationService
    EVERY = 1.day

    # tokens: a GithubExtras::Tokens for this user.
    attr_accessor :user, :tokens
    attr_reader :described

    validates :user, :tokens, presence: true

    private

    def execute
      @described = 0
      due.find_each do |repo|
        describe(repo)
      rescue ApplicationGateway::Unauthorized, ApplicationGateway::RateLimited
        break
      rescue ApplicationGateway::NotFound
        next
      end
    end

    def due
      user.github_repos.included_repos.with_entries.where("described_at IS NULL OR described_at < ?", EVERY.ago)
    end

    def describe(repo)
      token = tokens.for(repo)
      repo.update!(readme_line: ReadmeLine.of(GithubGateway.readme(repo.full_name, token: token)),
                   preview_image_url: GithubGateway.preview_image(repo.full_name, token: token),
                   described_at: Time.current)
      @described += 1
    end
  end
end
