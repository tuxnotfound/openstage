module Projects
  # What a project's builder sees on its own view: its colour, its numbers over
  # the last 30 days, and where its site visits stand. Site visits are counted
  # (by the script, on its website), paused (on Free, while another project is
  # the one site it counts), or off; a project without a website has nowhere
  # to count them.
  class GatherService < ApplicationService
    DAYS = 30

    attr_accessor :repo
    # project: its Progress::Projects entry, nil with nothing public yet;
    # site_state: :counting, :paused, :off or :no_website; free_site: the repo
    # Free counts when it is another one.
    attr_reader :project, :commits, :last_commit, :site_visits, :site_state, :free_site

    validates :repo, presence: true

    private

    def execute
      entries = user.entries.publicly_visible.without_tooling_noise
      @project = Progress::Projects.new(entries).find(repo.full_name)
      commits = entries.commits.where(repo_name: repo.full_name)
      @commits = commits.where(occurred_at: (today - (DAYS - 1)).in_time_zone(user.zone)..).count
      @last_commit = commits.maximum(:occurred_at)&.in_time_zone(user.zone)&.to_date
      @site_visits = repo.site_visit_days.where(day: (today - (DAYS - 1))..today).sum(:visits)
      @free_site = other_free_site
      @site_state = site_state_now
    end

    def user
      repo.user
    end

    def today
      Time.current.in_time_zone(user.zone).to_date
    end

    def other_free_site
      return if user.pro?

      counting = user.github_repos.site_set_up.busiest_site_first.first
      counting unless counting == repo
    end

    def site_state_now
      if repo.site_host.nil? then :no_website
      elsif repo.site_source.nil? then :off
      elsif free_site then :paused
      else :counting
      end
    end
  end
end
