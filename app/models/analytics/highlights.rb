module Analytics
  # What the builder's pages list as shipped and published over some days,
  # which analytics' chart marks (ProgressChart::Marks), as the dashboard's
  # does: each entry a Progress::TallyService::Item on its day in the
  # builder's zone, oldest first, of the rows the chart draws alone: a
  # project's, and with no project the builder's stage (CountService::PAGE).
  class Highlights
    # first: the first day, nil for every day up to last; rows: the
    # Progress::Rows the chart draws.
    def initialize(user, first:, last:, rows:)
      @user = user
      @first = first
      @last = last
      @keys = rows.map(&:key)
    end

    def all
      zone = @user.zone
      entries.map do |entry|
        Progress::TallyService::Item.new(entry: entry, date: entry.occurred_at.in_time_zone(zone).to_date,
                                         kind: Entry::SHIPPED_TYPES.include?(entry.entry_type) ? :shipped : :published, listed: true)
      end
    end

    private

    def entries
      return [] if @keys.empty?

      repos = @keys - [ CountService::PAGE ]
      @user.entries.listed_on_page.highlights.where(occurred_at: times, repo_name: @keys.include?(CountService::PAGE) ? [ nil, *repos ] : repos)
           .order(:occurred_at, :id)
    end

    def times
      zone = @user.zone
      @first&.in_time_zone(zone)...(@last + 1).in_time_zone(zone)
    end
  end
end
