module Analytics
  # Adds the builder's days that are over to their totals (PageDay, PageCount,
  # EntryClickDay), on the builder's day, and moves User#rolled_up_to past
  # them, in one transaction, so each row is added once however often this
  # runs. Their first run adds their whole history. A builder's days are those
  # of their zone now, so after a move the next run starts over from the raw
  # rows. Site visits keep no raw rows, so theirs stay as they were counted.
  class RollUpService < ApplicationService
    # A view can still be saving as its day ends.
    SETTLING = 5.minutes
    # Postgres will not group by a bare literal.
    OWN_PAGE = "CAST('#{CountService::PAGE}' AS varchar)".freeze

    attr_accessor :user

    validates :user, presence: true

    private

    def execute
      user.with_lock do
        start_over if user.rolled_up_zone != user.zone.name
        @until = SETTLING.ago.in_time_zone(user.zone).beginning_of_day
        add_everything if user.rolled_up_to.nil? || user.rolled_up_to < @until
      end
    end

    def start_over
      [ user.page_days, user.page_counts, user.entry_click_days ].each(&:delete_all)
      user.update_columns(rolled_up_to: nil)
    end

    def add_everything
      add_views(user.profile_views, OWN_PAGE)
      add_views(user.project_views, "project_views.repo_name")
      add_buttons
      add_badges
      add_entry_clicks
      user.update_columns(rolled_up_to: @until, rolled_up_zone: user.zone.name)
    end

    def add_views(all, page)
      views = fresh(all, :viewed_at)
      day = day_of("#{all.table_name}.viewed_at")
      add_days(views, page, day, all.table_name)
      add_counts(views, page, "'source'", day, referrer_of(all.table_name))
      add_counts(views.where.not(country: [ nil, "", *SiteVisits::PageView::NO_COUNTRY ]), page, "'country'", day, "#{all.table_name}.country")
    end

    def add_days(views, page, day, table)
      columns = [ page, day ].map { |sql| Arel.sql(sql) }
      rows = views.group(*columns).pluck(*columns, Arel.sql("COUNT(*)"), Arel.sql("COUNT(DISTINCT #{PageVisitor.of(table)})"))
      PageDay.add(rows.map { |name, date, views_on_day, visitors| { user_id: user.id, page: name, day: date, views: views_on_day, visitors: visitors } })
    end

    def add_buttons
      add_counts(fresh(user.project_clicks, :clicked_at), "project_clicks.repo_name", "'button'", day_of("project_clicks.clicked_at"), "project_clicks.kind")
    end

    # On the builder's own page: neither belongs to one of their projects.
    def add_badges
      add_counts(fresh(user.badge_impressions, :viewed_at), OWN_PAGE, "badge_impressions.kind", day_of("badge_impressions.viewed_at"), referrer_of("badge_impressions"))
    end

    def add_entry_clicks
      clicks = fresh(user.entry_clicks, :clicked_at).group(:entry_id, Arel.sql(day_of("entry_clicks.clicked_at"))).count
      EntryClickDay.add(clicks.map { |(entry_id, date), count| { user_id: user.id, entry_id: entry_id, day: date, clicks: count } })
    end

    # kind: its SQL, a column or a literal.
    def add_counts(rows, page, kind, day, value)
      columns = [ page, "CAST(#{kind} AS varchar)", day, value ].map { |sql| Arel.sql(sql) }
      counts = rows.group(*columns).count
      PageCount.add(counts.map { |(name, of, date, seen), count| { user_id: user.id, page: name, kind: of, day: date, value: seen, count: count } })
    end

    def referrer_of(table)
      "COALESCE(#{table}.referrer, '#{SiteVisitCount::DIRECT}')"
    end

    def fresh(rows, at)
      rows.where(at => user.rolled_up_to...@until)
    end

    def day_of(at)
      LocalDay.of(at, user.zone)
    end
  end
end
