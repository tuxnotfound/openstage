module Progress
  # Everything the public page shows below the builder's name: the window's
  # section (ComposeService), the numbers its chart can draw (NumbersService),
  # a card per project (SummarizeService) and the latest commits, grouped by
  # project and day.
  class GatherService < ApplicationService
    # Groups in Recent commits, and the commits read to fill them.
    RECENT_GROUPS = 8
    RECENT_LIMIT = 200

    # commits: that day's, newest first, as far as RECENT_LIMIT reached.
    Group = Data.define(:project, :date, :commits)

    # range: a Window range; repos: the projects in view, none for all.
    # reveal: a repo the builder hid, shown anyway (Entry.on_page). picked:
    # the numbers to chart, none for every one the page has.
    attr_accessor :user, :range, :repos, :reveal, :picked
    attr_reader :section, :numbers, :cards, :recent

    validates :user, presence: true

    private

    def execute
      compose = ComposeService.new(user: user, range: range, repos: Array(repos), rolling: true, reveal: reveal)
      return unless run(compose)

      @section = compose.section
      @numbers = NumbersService.new(user: user, section: section, picked: picked)
      return unless run(numbers)
      summarize = SummarizeService.new(user: user, projects: section.tally.projects.all, zone: section.tally.zone, reveal: reveal)
      return unless run(summarize)

      @cards = summarize.cards
      @recent = recent_groups
    end

    def run(service)
      service.call
      absorb_errors(service)
    end

    def recent_groups
      groups = {}
      recent_commits.each do |commit|
        key = [ commit.repo_name, commit.occurred_at.in_time_zone(section.tally.zone).to_date ]
        next unless groups.key?(key) || groups.size < RECENT_GROUPS

        (groups[key] ||= []) << commit
      end
      groups.filter_map do |(repo, date), commits|
        project = section.tally.projects.find(repo)
        Group.new(project: project, date: date, commits: commits) if project
      end
    end

    def recent_commits
      scope = user.entries.on_page(reveal: reveal).commits.chronological
      scope = scope.where(repo_name: repos) if Array(repos).any?
      scope.limit(RECENT_LIMIT)
    end
  end
end
