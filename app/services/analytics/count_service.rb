module Analytics
  # Each page's numbers per day, from a first day on: each project's commits
  # and the visits to its own website, then the visitors, views, new
  # followers and clicks out on Openstage, by their keys in Progress::Numbers.
  # A page is the builder's own, PAGE, or a project's, by its repo's full
  # name. Days are in the builder's zone.
  class CountService < ApplicationService
    PAGE = "page".freeze

    # from: the first day needed; nil for every day.
    attr_accessor :user, :from
    # {number's key => {page => {date => count}}}
    attr_reader :counts

    validates :user, presence: true

    private

    def execute
      @counts = {
        "commits" => commits,
        "visits" => site_visits,
        "visitors" => merge(daily(user.profile_views, "profile_views.viewed_at", distinct: "profile_views.ip_hash"),
                            daily(user.project_views, "project_views.viewed_at", "project_views.repo_name", distinct: "project_views.ip_hash")),
        "views" => merge(daily(user.profile_views, "profile_views.viewed_at"),
                         daily(user.project_views, "project_views.viewed_at", "project_views.repo_name")),
        "follows" => follows,
        "clicks" => merge(daily(user.project_clicks, "project_clicks.clicked_at", "project_clicks.repo_name"),
                          daily(user.entry_clicks.joins(:entry), "entry_clicks.clicked_at", "entries.repo_name"))
      }
    end

    # As the public page counts them: public, merges and dependency bumps left out.
    def commits
      merge(daily(user.entries.publicly_visible.without_tooling_noise.commits, "entries.occurred_at", "entries.repo_name"))
    end

    # Counted on the builder's day already, so read as they are.
    def site_visits
      scope = SiteVisitDay.joins(:github_repo).where(github_repos: { user_id: user.id })
      scope = scope.where(day: from..) if from
      merge(scope.group("github_repos.full_name", :day).sum(:visits))
    end

    # Confirmed in the window: for the builder's page, or for one project.
    def follows
      confirmed = user.subscriptions.confirmed
      merge(daily(confirmed.whole_page, "subscriptions.confirmed_at"),
            daily(confirmed.projects.joins(:github_repo), "subscriptions.confirmed_at", "github_repos.full_name"))
    end

    # {[page, date] => count}. Without a page column every row is the
    # builder's page; an entry with no project counts there too. A visitor is
    # a distinct IP hash, which changes daily, so each day counts its own.
    def daily(scope, at, page = nil, distinct: nil)
      scope = scope.where(at => from.in_time_zone(user.zone)..) if from
      grouped = scope.group(*[ page, day(at) ].compact.map { |sql| Arel.sql(sql) })
      counted = distinct ? grouped.distinct.count(distinct) : grouped.count
      counted.transform_keys { |key| page ? [ key.first || PAGE, key.last ] : [ PAGE, key ] }
    end

    def merge(*parts)
      parts.each_with_object({}) do |part, all|
        part.each { |(page, date), count| (all[page] ||= Hash.new(0))[date.to_date] += count }
      end
    end

    def day(at)
      LocalDay.of(at, user.zone)
    end
  end
end
