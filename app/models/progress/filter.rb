module Progress
  # The one set of params every chart page reads: the window (range), the
  # numbers drawn (show: their keys, comma-separated, in line order) and the
  # projects in view (projects: repos' full names, comma-separated, and on
  # analytics Analytics::CountService::PAGE for the builder's own page; none
  # for all of them). A page leaves its defaults out of its URL. Old links
  # keep working: repo[] and repo= name the projects where a page reads them,
  # analytics' pages[] its pages and its metric the one number it drew, and a
  # single show value is a list of one.
  class Filter
    # More projects than any page shows; a longer list is not a person. Both
    # chart APIs read their projects here, so neither takes more.
    MAX_PROJECTS = 50
    # Analytics' old name for a number, where it differs from the number's key.
    OLD_METRICS = { "site" => "visits" }.freeze

    # range: nil for the page's default; show: known keys, in line order.
    attr_reader :range, :show, :projects

    # repo: whether the page reads the old repo params (the dashboard's repo
    # filters its entries instead).
    def self.from(params, repo: true)
      new(range: params[:range], show: params[:show], projects: params[:projects].presence || (params[:repo] if repo))
    end

    # Analytics, whose old links named its pages pages[] and the one number
    # it drew metric.
    def self.from_analytics(params)
      metric = params[:metric].to_s
      new(range: params[:range], show: params[:show].presence || OLD_METRICS.fetch(metric, metric), projects: params[:projects].presence || params[:pages])
    end

    def initialize(range: nil, show: nil, projects: nil)
      @range = range.to_s.presence_in(Window::RANGES)
      @show = items(show).select { |key| Numbers.find(key) }.uniq
      @projects = items(projects).uniq.first(MAX_PROJECTS)
    end

    private

    # "a,b", ["a", "b"] or ["a,b"]: its items, trimmed, none blank.
    def items(value)
      Array(value).flat_map { |item| item.to_s.split(",") }.map(&:strip).compact_blank
    end
  end
end
