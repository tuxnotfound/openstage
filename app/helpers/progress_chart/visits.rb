module ProgressChart
  # One of the analytics page's charts: one line per page through one number,
  # a point per day or per week.
  class Visits
    include Plot

    LABELS = { "commits" => "Commits", "site" => "Site visits", "visitors" => "Visitors", "views" => "Views",
               "follows" => "New followers", "clicks" => "Clicks out" }.freeze
    # Where each number happens, as the tabs group them.
    GROUPS = { "commits" => "On GitHub", "site" => "On your websites", "visitors" => "On Openstage", "views" => "On Openstage",
               "follows" => "On Openstage", "clicks" => "On Openstage" }.freeze

    Line = Data.define(:name, :rank, :values)

    def initialize(report, metric)
      @report = report
      @metric = metric
    end

    # The pages picked with anything in the window.
    def lines
      @lines ||= @report.selected.filter_map do |page|
        values = @report.series(page, @metric)
        Line.new(name: page.name, rank: page.rank, values: values) if values.sum.positive?
      end
    end

    def aria_label
      "#{name} per #{window.unit_word} by page, #{window.words}"
    end

    def note
      "#{name} per #{window.unit_word}, one line per page."
    end

    def empty_note
      return "No site visits in the #{window.words}. Openstage's script counts them, set up from a project's Edit page." if @metric == "site"

      "No #{name.downcase} in the #{window.words}."
    end

    def name
      LABELS.fetch(@metric)
    end

    private

    def window
      @report.window
    end

    def buckets
      window.buckets
    end
  end
end
