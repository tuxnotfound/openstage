module Analytics
  # Each page's numbers per day, from a first day on: each project's commits,
  # its MRR and paying customers, and the visits and visitors to its own
  # website, then the visitors, views, new followers and clicks out on
  # Openstage, by their keys in Progress::Numbers.
  # A page is the builder's own, PAGE, or a project's, by its repo's full
  # name. Days are in the builder's zone. Openstage's own numbers come from
  # the daily totals, and from the raw rows since (Split).
  class CountService < ApplicationService
    PAGE = "page".freeze

    # from: the first day needed; nil for every day.
    attr_accessor :user, :from
    # counts: {number's key => {page => {date => count}}}; through and currency,
    # of the revenue, as Progress::Counts takes them, nil with none.
    attr_reader :counts, :through, :currency

    validates :user, presence: true

    private

    def execute
      visits, visitors = site_visits
      @counts = {
        "commits" => commits,
        "visits" => visits,
        "site_visitors" => visitors,
        "visitors" => visitors_of_pages,
        "views" => views,
        "follows" => follows,
        "clicks" => clicks,
        **revenue
      }
    end

    def revenue
      book = Revenue::Book.new(user)
      repos = book.repos
      return {} if repos.empty?

      levels = book.levels(repos, from: from)
      @through = book.read_day
      @currency = levels.currency
      levels.days(repos)
    end

    # As the public page counts them: public, merges and dependency bumps left out.
    def commits
      merge(daily(user.entries.publicly_counted.without_tooling_noise.commits, "entries.occurred_at", "entries.repo_name"))
    end

    # Counted on the builder's day already, so read as they are; the visits
    # and the visitors together.
    def site_visits
      scope = user.site_visit_days
      scope = scope.where(day: from..) if from
      sums = scope.group("github_repos.full_name", :day)
                  .pluck("github_repos.full_name", :day, Arel.sql("SUM(site_visit_days.visits)"), Arel.sql("SUM(site_visit_days.visitors)"))
      [ merge(sums.to_h { |page, date, visits, _| [ [ page, date ], visits ] }), merge(sums.to_h { |page, date, _, visitors| [ [ page, date ], visitors ] }) ]
    end

    # A visitor is a distinct PageVisitor, which changes daily, so each day
    # counts its own.
    def visitors_of_pages
      merge(page_days.to_h { |page, date, _, visitors| [ [ page, date ], visitors ] },
            by_day(split.raw(user.profile_views, "profile_views.viewed_at"), "profile_views.viewed_at", distinct: PageVisitor.of("profile_views")),
            by_day(split.raw(user.project_views, "project_views.viewed_at"), "project_views.viewed_at", "project_views.repo_name", distinct: PageVisitor.of("project_views")))
    end

    def views
      merge(page_days.to_h { |page, date, views, _| [ [ page, date ], views ] },
            by_day(split.raw(user.profile_views, "profile_views.viewed_at"), "profile_views.viewed_at"),
            by_day(split.raw(user.project_views, "project_views.viewed_at"), "project_views.viewed_at", "project_views.repo_name"))
    end

    def page_days
      @page_days ||= split.totals(user.page_days).pluck(:page, :day, :views, :visitors)
    end

    # A project's buttons and the links in its entries; an entry with no
    # project counts on the builder's page.
    def clicks
      merge(split.totals(user.page_counts.buttons).group(:page, :day).sum(:count),
            split.totals(user.entry_click_days).joins(:entry).group("entries.repo_name", :day).sum(:clicks).transform_keys { |repo, date| [ repo || PAGE, date ] },
            by_day(split.raw(user.project_clicks, "project_clicks.clicked_at"), "project_clicks.clicked_at", "project_clicks.repo_name"),
            by_day(split.raw(user.entry_clicks.joins(:entry), "entry_clicks.clicked_at"), "entry_clicks.clicked_at", "entries.repo_name"))
    end

    def split
      @split ||= Split.new(user, first: from)
    end

    # Confirmed: for the builder's page, or for one project.
    def follows
      confirmed = user.subscriptions.confirmed
      merge(daily(confirmed.whole_page, "subscriptions.confirmed_at"),
            daily(confirmed.projects.joins(:github_repo), "subscriptions.confirmed_at", "github_repos.full_name"))
    end

    def daily(scope, at, page = nil)
      by_day(from ? scope.where(at => from.in_time_zone(user.zone)..) : scope, at, page)
    end

    # {[page, date] => count}. Without a page column every row is the
    # builder's page; an entry with no project counts there too.
    def by_day(scope, at, page = nil, distinct: nil)
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
