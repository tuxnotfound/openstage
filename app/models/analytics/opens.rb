module Analytics
  # Who opened the analytics page in a window, for /admin: the builders in
  # the scope who opened any tab, then each tab in its order with its
  # builders, none left out. The page records an analytics_opened event once
  # per builder, tab and day (AnalyticsController); a tab Free does not open
  # counts its Go Pro view.
  class Opens
    Row = Data.define(:key, :label, :builders)

    def initialize(users, since:)
      @events = Event.named("analytics_opened").since(since).where(user_id: users.select(:id))
    end

    def builders
      @events.distinct.count(:user_id)
    end

    def tabs
      counts = @events.group(:detail).distinct.count(:user_id)
      Tab::ALL.map { |tab| Row.new(key: tab.key, label: tab.label, builders: counts.fetch(tab.key, 0)) }
    end
  end
end
