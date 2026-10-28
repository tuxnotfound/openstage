module SiteVisits
  # Where a project's site visits come from, as its builder sets it:
  # Openstage's script or nowhere ("off"). The first time it becomes the
  # script, its setup time is kept for good. Free counts the one project set
  # up first (Slot): setting up any other is refused, with Pro offered.
  # Whether its page shows them is one of its numbers
  # (Projects::ShowNumberService).
  class ConfigureService < ApplicationService
    attr_accessor :repo, :source

    validates :repo, presence: true
    validates :source, inclusion: { in: [ *GithubRepo::SITE_SOURCES, "off" ] }, allow_nil: true
    validate :a_website_to_count_on, :one_project_on_free

    private

    def execute
      repo.site_source = source == "off" ? nil : source if source
      if script?
        repo.site_token ||= "os_#{SecureRandom.alphanumeric(12).downcase}"
        repo.site_set_up_at ||= Time.current
      end
      repo.save
      absorb_errors(repo)
    end

    def a_website_to_count_on
      errors.add(:base, "Add #{repo.name}'s website first: the script counts only there.") if script? && repo.site_host.nil?
    end

    def one_project_on_free
      counted = Slot.new(repo.user).instead_of(repo) if script?
      errors.add(:base, "Free counts site visits for one project, #{counted.name}. Go Pro to count them for every project.") if counted
    end

    def script?
      repo && source == "script"
    end
  end
end
