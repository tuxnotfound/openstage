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
      transaction do
        hold_builder if script?
        save_source if errors.none?
      end
    end

    # Two setups sent at once both pass the check above, and Free would count
    # both. With its builder's row locked, the later one reads the slot the
    # first took, and is refused.
    def hold_builder
      repo.user.lock!
      one_project_on_free
    end

    def save_source
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
