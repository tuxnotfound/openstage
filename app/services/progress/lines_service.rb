module Progress
  # The lines the builder's dashboard chart draws over its section
  # (ComposeService): each project's commits and site visits, the numbers
  # the builder switched off for each, and what each project's table row
  # needs, its repo, so its switches can save.
  class LinesService < ApplicationService
    attr_accessor :user, :section
    # repos: {repo's full name => GithubRepo} for the projects in view;
    # site: a SiteVisits::GatherService, nil with no site visits counted;
    # hidden: {repo's full name => the numbers switched off}.
    attr_reader :repos, :site, :hidden

    validates :user, :section, presence: true

    private

    def execute
      @repos = user.github_repos.where(full_name: section.tally.projects.all.map(&:repo)).index_by(&:full_name)
      @hidden = repos.transform_values(&:dashboard_hidden)
      site = SiteVisits::GatherService.new(user: user, section: section, dashboard: true)
      site.call
      return unless absorb_errors(site)

      @site = site if site.any?
    end
  end
end
