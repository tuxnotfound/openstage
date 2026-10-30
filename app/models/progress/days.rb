module Progress
  # The days a builder picks for a window on the calendar, as a chart page's
  # range param carries them ("2026-10-03..2026-10-28") or the form without
  # the script sends them (from and to). Both are real days; a reversed pair
  # swaps, and the first comes no earlier than EARLIEST. Anything else is no
  # pick, and the page keeps its default, as for a range it does not know.
  class Days
    # Before any history a page could count.
    EARLIEST = Date.new(2008, 1, 1)
    DAY = /\A(\d{4})-(\d{2})-(\d{2})\z/
    SEPARATOR = "..".freeze

    attr_reader :from, :to

    # "2026-10-03..2026-10-28"; nil for anything else.
    def self.parse(text)
      from, to, *rest = text.to_s.split(SEPARATOR, -1)
      of(from, to) if rest.empty?
    end

    # Two days as "2026-10-03", either order; nil unless both are real.
    def self.of(from, to)
      first, last = [ day(from), day(to) ]
      return unless first && last

      first, last = [ first, last ].minmax
      new([ first, EARLIEST ].max, last) if last >= EARLIEST
    end

    def self.day(text)
      match = DAY.match(text.to_s)
      return unless match

      year, month, date = match.captures.map(&:to_i)
      Date.new(year, month, date) if Date.valid_date?(year, month, date)
    end

    def initialize(from, to)
      @from = from
      @to = to
    end

    # The same days up to today; nil when they start after it.
    def upto(today)
      self.class.new(from, [ to, today ].min) unless from > today
    end

    def count
      (to - from).to_i + 1
    end

    def to_s
      "#{from.iso8601}#{SEPARATOR}#{to.iso8601}"
    end
  end
end
