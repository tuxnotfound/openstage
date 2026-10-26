module ProgressChart
  # Site visits on their own: one line per project, in its colour and dotted,
  # as visits are beside commits, through the visits per point of their window.
  class SiteVisits
    include Plot

    Line = Data.define(:name, :rank, :values) do
      def dashed?
        true
      end
    end

    # tally: a SiteVisits::TallyService; projects: the section's
    # Progress::Projects, for each line's name and colour.
    def initialize(tally, projects:)
      @tally = tally
      @projects = projects
    end

    def lines
      @lines ||= @tally.lines.filter_map do |repo, values|
        project = @projects.find(repo)
        Line.new(name: project&.name || repo.split("/").last, rank: project&.rank, values: values) if values.sum.positive?
      end
    end

    def paths
      super.map { |d, rank| [ d, rank, true ] }
    end

    def aria_label
      "Site visits per #{unit} by project, #{words}"
    end

    def note
      where = @tally.lines.one? ? "Visits to #{@tally.repos.first.site_host}" : "Visits to each project's website"
      "#{where} per #{unit}, counted by Openstage's script. A visitor is one browser on one day; bots left out."
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
