module ProgressChart
  # The analytics page's chart: one line per page through the number picked,
  # a point per day or per week.
  class Visits
    include Plot

    LABELS = { "visitors" => "Visitors", "views" => "Page views", "follows" => "New followers", "clicks" => "Clicks out",
               "site" => "Site visits" }.freeze

    Line = Data.define(:name, :rank, :values)

    def initialize(report)
      @report = report
    end

    # The pages picked with anything in the window.
    def lines
      @lines ||= @report.selected.filter_map do |page|
        values = @report.series(page)
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
      "No #{name.downcase} in the #{window.words}."
    end

    def name
      LABELS.fetch(@report.metric)
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
