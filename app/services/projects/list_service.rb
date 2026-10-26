module Projects
  # The builder's projects as the dashboard's table lists them: the repo
  # behind each project in a section (Progress::ComposeService), so its row
  # can edit it and switch it, and the repos with work the builder hid from
  # their page, so they can come back.
  class ListService < ApplicationService
    attr_accessor :user, :section
    # repos: {repo's full name => GithubRepo}; off_page: GithubRepos.
    attr_reader :repos, :off_page

    validates :user, :section, presence: true

    private

    def execute
      @repos = user.github_repos.where(full_name: section.tally.projects.all.map(&:repo)).index_by(&:full_name)
      @off_page = user.github_repos.with_entries.where(included: false).order(:name).to_a
    end
  end
end
