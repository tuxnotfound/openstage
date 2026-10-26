module SiteVisits
  # A project's site visits over one of its page's windows (Progress::Window):
  # the visits per point, by day, week or month, from the first day counted,
  # and the window's visits and visitors. A visitor is one browser on one day,
  # so the window's visitors are its days' visitors added up. Only for a
  # project whose page shows them (GithubRepo#site_visits_public?).
  class TallyService < ApplicationService
    attr_accessor :repo, :range
    # values: visits per bucket, in the window's order.
    attr_reader :window, :values, :visits, :visitors

    validates :repo, presence: true
    validate :shown_on_its_page

    private

    def shown_on_its_page
      errors.add(:repo, "does not show site visits on its page") if repo && !repo.site_visits_public?
    end

    def execute
      today = Time.current.in_time_zone(repo.user.zone).to_date
      @window = Progress::Window.new(range: range, today: today, first_activity: repo.site_visit_days.minimum(:day))
      days = repo.site_visit_days.where(day: window.days).pluck(:day, :visits, :visitors)
      @values = window.buckets.map { |bucket| days.sum { |day, count, _| (bucket.first..bucket.last).cover?(day) ? count : 0 } }
      @visits = days.sum { |_, count, _| count }
      @visitors = days.sum(&:last)
    end
  end
end
