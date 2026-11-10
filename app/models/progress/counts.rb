module Progress
  # A builder's numbers per project and day, as their pages count them, and
  # the first day each project counted each one, ever. Days are in the
  # builder's zone; a project is its repo's full name. A level
  # (Numbers::Number#level?) stands at a point in time: over some days it is
  # what it stood at on the last, never their sum.
  class Counts
    # currency: the one the money numbers are in, in its units.
    attr_reader :currency

    # days: {number's key => {repo => {date => count}}};
    # firsts: {number's key => {repo => date}}; through: the last day the levels
    # were read, whose value stands for the days after it; a day before it
    # with no value stood at nothing.
    def initialize(days: {}, firsts: {}, through: nil, currency: nil)
      @days = days
      @firsts = firsts
      @through = through
      @currency = currency
    end

    # A project's count over some days; nil days for every day counted.
    def sum(key, repo, days = nil)
      return at(key, repo, days&.last || @through) if level?(key)

      daily = daily(key, repo)
      days ? daily.sum { |date, count| days.cover?(date) ? count : 0 } : daily.values.sum
    end

    # Whether a project's count reads above zero over some days, as the pages
    # write it: a flow's sum, a level on any of them; nil days for every day
    # counted, where a level is where it stands today.
    def above_zero?(key, repo, days = nil)
      value = level?(key) && days ? peak(key, repo, days) : sum(key, repo, days)
      value.round.positive?
    end

    # The first day any of these projects counted the number; nil for none.
    def first_day(key, repos)
      repos.filter_map { |repo| @firsts.dig(key, repo) }.min
    end

    # A project's count at each point: the sum of its days, or, averaged,
    # each day's 7-day average, as a window drawn by day draws commits.
    def per_point(key, repo, buckets, average: false)
      return buckets.map { |bucket| at(key, repo, bucket.last) } if level?(key)

      daily = daily(key, repo)
      span = Window::AVERAGE
      buckets.map do |bucket|
        next (bucket.first..bucket.last).sum { |day| daily.fetch(day, 0) } unless average

        (0...span).sum { |back| daily.fetch(bucket.first - back, 0) } / span.to_f
      end
    end

    # A value of a number as the pages write it.
    def written(number, value)
      return Revenue::Money.write(value, currency) if number.money?

      ActiveSupport::NumberHelper.number_to_delimited(value)
    end

    private

    def level?(key)
      Numbers.find(key).level?
    end

    def at(key, repo, day)
      daily(key, repo).fetch([ day, @through ].compact.min, 0)
    end

    # A level's highest over some days; the days past the last read stand
    # where it stood then.
    def peak(key, repo, days)
      last = [ days.last, @through ].compact.min
      first = [ days.first, last ].min
      daily(key, repo).filter_map { |date, count| count if date.between?(first, last) }.max || 0
    end

    def daily(key, repo)
      @days.dig(key, repo) || {}
    end
  end
end
