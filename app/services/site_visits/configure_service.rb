module SiteVisits
  # A project's site visits as its builder sets them: where they come from,
  # Openstage's script or nowhere ("off"), and whether its page shows them.
  # Free counts one site: setting up a second refuses, unless asked to count
  # this one instead, which turns the other's source off.
  class ConfigureService < ApplicationService
    attr_accessor :repo, :source, :shown, :count_here

    validates :repo, presence: true
    validates :source, inclusion: { in: [ *GithubRepo::SITE_SOURCES, "off" ] }, allow_nil: true
    validate :a_website_to_count_on, :one_site_on_free

    private

    def execute
      transaction do
        others.update_all(site_source: nil) if count_here
        repo.site_source = source == "off" ? nil : source if source
        repo.site_token ||= "os_#{SecureRandom.alphanumeric(12).downcase}" if repo.site_source
        repo.site_visits_shown = shown unless shown.nil?
        repo.save
        absorb_errors(repo)
      end
    end

    def a_website_to_count_on
      errors.add(:base, "Add #{repo.name}'s website first: the script counts only there.") if script? && repo.site_host.nil?
    end

    def one_site_on_free
      return unless script? && !count_here && others.exists?

      errors.add(:base, "Free counts one site. Count this one instead, or go Pro to count both.")
    end

    def script?
      repo && source == "script"
    end

    # The builder's other projects set up, which Free would also count.
    def others
      repo.user.pro? ? GithubRepo.none : repo.user.github_repos.site_set_up.where.not(id: repo.id)
    end
  end
end
