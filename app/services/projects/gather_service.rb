module Projects
  # What a project's builder sees on its own view: its colour, its numbers over
  # the last 30 days, and where its site visits stand. Site visits are counted
  # (by the script, on its website), paused (the script on while Free counts
  # another project, SiteVisits::Slot), or off; a project without a website
  # has nowhere to count them.
  class GatherService < ApplicationService
    DAYS = 30

    attr_accessor :repo
    # project: its Progress::Projects entry, nil with nothing public yet;
    # last_site_visit: when the latest counted; site_state: :counting,
    # :paused, :off or :no_website; free_project: the project Free counts
    # instead of this one, nil when this one can count.
    attr_reader :project, :commits, :last_commit, :site_visits, :last_site_visit, :site_state, :free_project

    validates :repo, presence: true

    private

    def execute
      entries = user.entries.publicly_visible.without_tooling_noise
      @project = Progress::Projects.new(entries).find(repo.full_name)
      commits = entries.commits.where(repo_name: repo.full_name)
      @commits = commits.where(occurred_at: (today - (DAYS - 1)).in_time_zone(user.zone)..).count
      @last_commit = commits.maximum(:occurred_at)&.in_time_zone(user.zone)&.to_date
      @site_visits = repo.site_visit_days.where(day: (today - (DAYS - 1))..today).sum(:visits)
      @last_site_visit = repo.site_visit_days.maximum(:updated_at)
      slot = SiteVisits::Slot.new(user)
      @free_project = slot.instead_of(repo)
      @site_state = site_state_now(slot.state(repo))
    end

    def user
      repo.user
    end

    def today
      Time.current.in_time_zone(user.zone).to_date
    end

    # A paused project stays paused whatever its website; otherwise the
    # script has nowhere to count without one.
    def site_state_now(state)
      state != :paused && repo.site_host.nil? ? :no_website : state
    end
  end
end
