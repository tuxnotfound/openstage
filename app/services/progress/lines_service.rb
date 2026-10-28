module Progress
  # The lines the builder's dashboard chart draws over its section
  # (ComposeService): each project's commits and site visits, the numbers
  # the builder hid from visitors for each, and what the table under it needs:
  # each project's repo, so its switches can save, and the repos hidden from
  # the builder's page, so they can come back.
  class LinesService < ApplicationService
    attr_accessor :user, :section
    # repos: {repo's full name => GithubRepo} for the projects in view;
    # off_page: the repos with work that the builder hid from their page;
    # site: a SiteVisits::GatherService, nil with no site visits counted;
    # hidden: {repo's full name => the numbers hidden from visitors}.
    attr_reader :repos, :off_page, :site, :hidden

    validates :user, :section, presence: true

    private

    def execute
      @repos = user.github_repos.where(full_name: section.tally.projects.all.map(&:repo)).index_by(&:full_name)
      @off_page = user.github_repos.with_entries.where(included: false).order(:name).to_a
      @hidden = repos.transform_values(&:hidden_numbers)
      site = SiteVisits::GatherService.new(user: user, section: section, dashboard: true)
      site.call
      return unless absorb_errors(site)

      @site = site if site.any?
    end
  end
end
