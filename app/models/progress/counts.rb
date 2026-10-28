module Progress
  # A builder's numbers per project and day, as their pages count them, and
  # the first day each project counted each one, ever. Days are in the
  # builder's zone; a project is its repo's full name.
  class Counts
    # days: {number's key => {repo => {date => count}}};
    # firsts: {number's key => {repo => date}}.
    def initialize(days: {}, firsts: {})
      @days = days
      @firsts = firsts
    end

    # A project's count over some days; nil days for every day counted.
    def sum(key, repo, days = nil)
      daily = daily(key, repo)
      days ? daily.sum { |date, count| days.cover?(date) ? count : 0 } : daily.values.sum
    end

    # The first day any of these projects counted the number; nil for none.
    def first_day(key, repos)
      repos.filter_map { |repo| @firsts.dig(key, repo) }.min
    end

    # A project's count at each point: the sum of its days, or, averaged,
    # each day's 7-day average, as the 30-day view draws commits.
    def per_point(key, repo, buckets, average: false)
      daily = daily(key, repo)
      span = ProgressChart::Trend::AVERAGE
      buckets.map do |bucket|
        next (bucket.first..bucket.last).sum { |day| daily.fetch(day, 0) } unless average

        (0...span).sum { |back| daily.fetch(bucket.first - back, 0) } / span.to_f
      end
    end

    private

    def daily(key, repo)
      @days.dig(key, repo) || {}
    end
  end
end
