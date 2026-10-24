module Analytics
  # Each page's numbers per day, over a window and the one before it: the
  # visitors, page views, new followers and clicks out that the analytics page
  # shows. A page is the builder's own, PAGE, or a project's, by its repo's
  # full name. Days are in the builder's zone.
  class CountService < ApplicationService
    METRICS = %w[visitors views follows clicks].freeze
    PAGE = "page".freeze

    attr_accessor :user, :window
    # {metric => {page => {date => count}}}
    attr_reader :counts

    validates :user, :window, presence: true

    private

    def execute
      @counts = {
        "visitors" => merge(daily(user.profile_views, "profile_views.viewed_at", distinct: "profile_views.ip_hash"),
                            daily(user.project_views, "project_views.viewed_at", "project_views.repo_name", distinct: "project_views.ip_hash")),
        "views" => merge(daily(user.profile_views, "profile_views.viewed_at"),
                         daily(user.project_views, "project_views.viewed_at", "project_views.repo_name")),
        "follows" => follows,
        "clicks" => merge(daily(user.project_clicks, "project_clicks.clicked_at", "project_clicks.repo_name"),
                          daily(user.entry_clicks.joins(:entry), "entry_clicks.clicked_at", "entries.repo_name"))
      }
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
      grouped = scope.where(at => times).group(*[ page, day(at) ].compact.map { |sql| Arel.sql(sql) })
      counted = distinct ? grouped.distinct.count(distinct) : grouped.count
      counted.transform_keys { |key| page ? [ key.first || PAGE, key.last ] : [ PAGE, key ] }
    end

    def merge(*parts)
      parts.each_with_object(Hash.new { |hash, page| hash[page] = Hash.new(0) }) do |part, all|
        part.each { |(page, date), count| all[page][date.to_date] += count }
      end
    end

    def times
      window.span.first.in_time_zone(user.zone)..window.today.in_time_zone(user.zone).end_of_day
    end

    # The local day of a UTC timestamp column.
    def day(at)
      "DATE((#{at} AT TIME ZONE 'UTC') AT TIME ZONE #{ActiveRecord::Base.connection.quote(user.zone.tzinfo.identifier)})"
    end
  end
end
