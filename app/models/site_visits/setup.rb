module SiteVisits
  # The page Set up site visits, for one builder (SiteVisitsSetupsController):
  # the projects to pick from, the one picked, and the step it is at.
  #
  # The projects are the ones on their stage, by name, as the app lists repos
  # in a field, and the one a link asked for even while it is off the stage,
  # since its own view offers the setup too. Picked: the one asked for; else,
  # on Free, the one Free counts (Slot), the only one it can set up; else the
  # first with a website; else the first.
  #
  # Its steps: :pick, the project and its website, until Openstage's script
  # counts on that website; :line, the line to paste, until a visit comes;
  # :done, once the first has. change: the builder opened the first again.
  class Setup
    attr_reader :user

    # repo: the project picked, when the caller has it already, as a refused
    # setup does, with what the builder typed.
    def initialize(user, project_id: nil, repo: nil, change: false)
      @user = user
      @project_id = project_id
      @repo = repo
      @change = change
    end

    def projects
      @projects ||= begin
        listed = user.github_repos.included_repos.with_entries.to_a
        listed << asked if asked && listed.none? { |each| each.id == asked.id }
        listed.sort_by { |each| [ each.name.downcase, each.full_name ] }
      end
    end

    # nil for a builder with no project yet.
    def repo
      @repo ||= asked || free_slot || projects.find(&:site_host) || projects.first
    end

    def step
      return :pick if @change || !counting?

      repo.site_first_visit_at ? :done : :line
    end

    private

    def asked
      return @asked if defined?(@asked)

      @asked = (user.github_repos.find_by(id: @project_id) if @project_id.present?)
    end

    def free_slot
      projects.find { |each| each.id == slot.repo.id } if !user.pro? && slot.repo
    end

    def counting?
      repo.present? && repo.site_host.present? && slot.counts?(repo)
    end

    def slot
      @slot ||= Slot.new(user)
    end
  end
end
