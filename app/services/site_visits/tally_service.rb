module SiteVisits
  # Projects' site visits over one of their pages' windows (Progress::Window),
  # each on its own: the visits per point, by day, week or month, from the
  # first day any of them counted, and the window's visits and visitors
  # together. A visitor is one browser on one day, so the window's visitors
  # are its days' visitors added up.
  class TallyService < ApplicationService
    # repos: one builder's GithubRepos.
    attr_accessor :repos, :range
    # lines: {repo's full name => visits per bucket}, in the window's order.
    attr_reader :window, :lines, :visits, :visitors

    validates :repos, presence: true

    private

    def execute
      days = SiteVisitDay.where(github_repo_id: repos.map(&:id))
      @window = Progress::Window.new(range: range, today: Time.current.in_time_zone(repos.first.user.zone).to_date,
                                     first_activity: days.minimum(:day))
      rows = days.where(day: window.days).pluck(:github_repo_id, :day, :visits, :visitors)
      @lines = repos.to_h { |repo| [ repo.full_name, per_bucket(rows.select { |id, *| id == repo.id }) ] }
      @visits = rows.sum { |_, _, count, _| count }
      @visitors = rows.sum(&:last)
    end

    def per_bucket(rows)
      window.buckets.map { |bucket| rows.sum { |_, day, count, _| (bucket.first..bucket.last).cover?(day) ? count : 0 } }
    end
  end
end
