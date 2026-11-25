module SiteVisits
  # The first step of Set up site visits: a project's website, then
  # Openstage's script on it (ConfigureService), both or neither. The website
  # is kept as the builder's own (GithubRepo#website_edit) only when it is not
  # what the app reads already, so one taken from GitHub keeps following
  # GitHub, as a field left blank on the project's own view does.
  class SetUpService < ApplicationService
    attr_accessor :repo, :website

    validates :repo, presence: true

    private

    def execute
      transaction do
        save_website
        pick_script if errors.none?
      end
    end

    def save_website
      return if website.to_s.strip == repo.website.to_s

      repo.update(website_edit: website)
      absorb_errors(repo)
    end

    def pick_script
      configure = ConfigureService.new(repo: repo, source: "script")
      configure.call
      absorb_errors(configure)
    end
  end
end
