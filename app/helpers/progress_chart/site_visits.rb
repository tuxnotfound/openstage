module ProgressChart
  # A project's site visits on its page: one line, in the project's colour,
  # through the visits per point of the page's window.
  class SiteVisits
    include Plot

    Line = Data.define(:name, :rank, :values)

    # tally: a SiteVisits::TallyService; name and rank: the project's.
    def initialize(tally, name:, rank:)
      @tally = tally
      @name = name
      @rank = rank
    end

    def lines
      @lines ||= @tally.visits.positive? ? [ Line.new(name: @name, rank: @rank, values: @tally.values) ] : []
    end

    def aria_label
      "Site visits per #{unit}, #{words}"
    end

    def note
      "Visits to #{@tally.repo.site_host} per #{unit}, counted by Openstage's script on the site. " \
        "A visitor is one browser on one day; bots left out."
    end

    def empty_note
      "No site visits in the #{words}."
    end

    private

    def buckets
      @tally.window.buckets
    end

    def unit
      @tally.window.unit
    end

    def words
      @tally.window.labels.words
    end
  end
end
