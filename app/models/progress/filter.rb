module Progress
  # The one set of params every chart page reads: the window (range), the
  # numbers drawn (show: their keys, comma-separated, in line order) and the
  # projects in view (projects: repos' full names, comma-separated; none for
  # all of them). A page leaves its defaults out of its URL. Old links keep
  # working: repo[] and repo= name the projects where a page reads them, and
  # a single show value is a list of one.
  class Filter
    # More projects than any page shows; a longer list is not a person.
    MAX_PROJECTS = 50

    # range: nil for the page's default; show: known keys, in line order.
    attr_reader :range, :show, :projects

    # repo: whether the page reads the old repo params (the dashboard's repo
    # filters its entries instead).
    def self.from(params, repo: true)
      new(range: params[:range], show: params[:show], projects: params[:projects].presence || (params[:repo] if repo))
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
