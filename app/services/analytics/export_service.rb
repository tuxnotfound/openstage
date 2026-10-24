module Analytics
  # The analytics page: the report for the view asked for (ReportService),
  # which the server renders first, and the data behind every other view,
  # which the page's script switches to without a request. That data is each
  # page's daily rows over the longest window and the one before it.
  class ExportService < ApplicationService
    LONGEST = "90d".freeze

    attr_accessor :user, :range, :picked, :metric
    attr_reader :report, :payload

    validates :user, presence: true

    private

    def execute
      @report = ReportService.new(user: user, range: range, picked: picked, metric: metric)
      report.call
      return unless absorb_errors(report)

      count = CountService.new(user: user, window: longest)
      count.call
      return unless absorb_errors(count)

      @payload = {
        today: longest.today.iso8601, range: report.window.range, metric: report.metric,
        selected: report.selected.size == report.pages.size ? [] : report.selected.map(&:key),
        pages: report.pages.map(&:to_h), counts: iso_days(count.counts),
        sources: visits(:referrer) { |host| ReferrerClassifier.classify(host) },
        countries: visits(:country, &:itself).reject { |row| row[2].blank? },
        links: entry_links + button_links, badges: badges
      }
    end

    def longest
      @longest ||= Window.new(range: LONGEST, today: Time.current.in_time_zone(user.zone).to_date)
    end

    def iso_days(counts)
      counts.transform_values { |pages| pages.transform_values { |days| days.transform_keys(&:iso8601) } }
    end

    # [page, day, label, count] for the builder's page and each project's.
    def visits(column)
      [ [ user.profile_views, nil ], [ user.project_views, "project_views.repo_name" ] ].flat_map do |scope, page|
        table = scope.table_name
        grouped = scope.where(viewed_at: times).group(*[ page, day("#{table}.viewed_at"), "#{table}.#{column}" ].compact.map { |sql| Arel.sql(sql) }).count
        grouped.map do |key, count|
          *repo, date, value = key
          [ repo.first || CountService::PAGE, date.to_date.iso8601, yield(value), count ]
        end
      end
    end

    # [key, title, page, day, count]; an entry with no project counts for the builder's page.
    def entry_links
      grouped = user.entry_clicks.joins(:entry).where(clicked_at: times)
                    .group(Arel.sql("entries.id"), Arel.sql("entries.title"), Arel.sql("entries.repo_name"), Arel.sql(day("entry_clicks.clicked_at"))).count
      grouped.map { |(id, title, repo, date), count| [ "entry-#{id}", title, repo || CountService::PAGE, date.to_date.iso8601, count ] }
    end

    def button_links
      repos = user.github_repos.index_by(&:full_name)
      user.project_clicks.where(clicked_at: times).group(:repo_name, :kind, Arel.sql(day("project_clicks.clicked_at"))).count.map do |(repo, kind, date), count|
        [ "#{kind}-#{repo}", button_title(kind, repos[repo]), repo, date.to_date.iso8601, count ]
      end
    end

    def button_title(kind, repo)
      return "View on GitHub" unless kind == "visit"

      url = repo&.outbound_url("visit")
      "Visit #{url ? URI(url).host : 'the website'}"
    rescue URI::InvalidURIError
      "Visit the website"
    end

    # [kind, day, referrer, count]
    def badges
      user.badge_impressions.where(viewed_at: times).group(:kind, Arel.sql(day("badge_impressions.viewed_at")), :referrer).count
          .map { |(kind, date, referrer), count| [ kind, date.to_date.iso8601, referrer, count ] }
    end

    def day(column)
      LocalDay.of(column, user.zone)
    end

    def times
      longest.days.first.in_time_zone(user.zone)..longest.today.in_time_zone(user.zone).end_of_day
    end
  end
end
