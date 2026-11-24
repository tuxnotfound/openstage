module Feed
  # A page of the feed as one card per builder and day, newest first. A card
  # holds its builder's whole day, so a builder whose script commits every few
  # minutes still takes one card. The page reads one day at a time, so it costs
  # what a few days hold, never the whole table.
  class ListService < ApplicationService
    # One builder's day: the newest entries in it, what the day holds in all,
    # and its newest entry's time, which orders the cards.
    Card = Data.define(:user, :date, :latest, :entries, :commits, :shipped, :total) do
      def published = total - commits - shipped
      def more = total - entries.size
    end

    PER_PAGE = 10
    SHOWN = 3
    COMMIT_SQL = "entries.source = 'github' AND entries.entry_type = 'shipped'".freeze
    TOTALS_SQL = [
      "MAX(entries.occurred_at)",
      "COUNT(*) FILTER (WHERE #{COMMIT_SQL})",
      "COUNT(*) FILTER (WHERE entries.entry_type IN (#{Entry::SHIPPED_TYPES.map { |type| "'#{type}'" }.join(', ')}) AND NOT (#{COMMIT_SQL}))",
      "COUNT(*)",
      "(ARRAY_AGG(entries.id ORDER BY entries.occurred_at DESC, entries.id DESC))[1:#{SHOWN}]"
    ].map { |sql| Arel.sql(sql) }.freeze

    # scope: the entries to show. before and builder: the last card shown,
    # by its newest entry's time (ISO 8601) and its builder's id, to read on
    # from; both blank for the first page.
    attr_accessor :scope, :before, :builder
    attr_writer :per_page
    attr_reader :cards, :next_cursor

    # Not presence: a relation's blank? would load every entry it holds.
    validate :scope_given
    validates :per_page, numericality: { only_integer: true, greater_than: 0 }
    validates :builder, numericality: { only_integer: true }, allow_blank: true
    validate :before_is_a_time

    def per_page
      @per_page || PER_PAGE
    end

    private

    def execute
      found = read_days
      @cards = to_cards(found.first(per_page))
      last = @cards.last
      @next_cursor = { before: last.latest.iso8601(6), builder: last.user.id } if found.size > per_page
    end

    # One more card than the page shows, so the page knows whether more follow.
    def read_days
      found = []
      day = before_time&.to_date || newest_day_before(nil)
      while day && found.size <= per_page
        found.concat(day_totals(day, cursor: found.empty? && before_time))
        day = newest_day_before(day.beginning_of_day)
      end
      found
    end

    def newest_day_before(time)
      days = time ? scope.where(occurred_at: ...time) : scope
      days.order(occurred_at: :desc).pick(:occurred_at)&.to_date
    end

    # Every builder's totals for the day, newest first; on the cursor's day,
    # only the cards after it.
    def day_totals(day, cursor:)
      totals = scope.where(occurred_at: day.all_day).group(:user_id)
                    .order(Arel.sql("MAX(entries.occurred_at) DESC, entries.user_id DESC"))
      if cursor
        totals = totals.having("(MAX(entries.occurred_at), entries.user_id) < (?, ?)", cursor, builder.to_i)
      end
      totals.pluck(:user_id, *TOTALS_SQL).map { |row| [ day, *row ] }
    end

    def to_cards(found)
      entries = Entry.includes(:user).where(id: found.flat_map(&:last)).index_by(&:id)
      found.map do |day, _user_id, latest, commits, shipped, total, ids|
        shown = entries.values_at(*ids)
        Card.new(user: shown.first.user, date: day, latest:, entries: shown, commits:, shipped:, total:)
      end
    end

    def scope_given
      errors.add(:scope, :blank) if scope.nil?
    end

    def before_time
      return if before.blank?

      @before_time ||= Time.zone.iso8601(before.to_s)
    end

    def before_is_a_time
      before_time
    rescue ArgumentError
      errors.add(:before, :invalid)
    end
  end
end
