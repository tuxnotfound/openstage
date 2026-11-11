module Progress
  # What the stage's list of projects shows (ListService): its order, the
  # name searched for, whether only live projects show, and which page of
  # them. Read from a page's or the API's params, so an address no one could
  # have meant (an unknown order, page 0) still opens a list. A link leaves
  # the defaults out of its address. On the dashboard, whose entries read q
  # already, its params carry a prefix (DASHBOARD).
  class Listing
    # Latest commit first, the most commits over the cards' 52 weeks first,
    # or by name. The first is the default.
    SORTS = %w[latest commits name].freeze
    # Longer than any repo's name, which GitHub caps at 100.
    QUERY_LENGTH = 100
    # What a link or a form sends for the live projects alone.
    LIVE_VALUES = %w[1 true].freeze
    # Its params, and their prefix on the dashboard.
    PARAMS = %w[sort q live page].freeze
    DASHBOARD = "list_".freeze

    attr_reader :sort, :query, :live, :page

    def self.names(prefix = "")
      PARAMS.map { |name| "#{prefix}#{name}" }
    end

    def self.from(params, prefix = "")
      new(sort: params[:"#{prefix}sort"], query: params[:"#{prefix}q"], live: params[:"#{prefix}live"], page: params[:"#{prefix}page"])
    end

    def initialize(sort: nil, query: nil, live: nil, page: nil)
      @sort = sort.to_s.presence_in(SORTS) || SORTS.first
      @query = query.to_s.strip.first(QUERY_LENGTH)
      @live = LIVE_VALUES.include?(live.to_s)
      @page = [ page.to_i, 1 ].max
    end

    def to_params(prefix: "")
      { sort: (sort unless sort == SORTS.first), q: query.presence, live: ("1" if live), page: (page if page > 1) }.compact
        .transform_keys { |key| :"#{prefix}#{key}" }
    end

    def with(sort: @sort, query: @query, live: @live, page: @page)
      self.class.new(sort: sort, query: query, live: live, page: page)
    end

    def ==(other)
      other.is_a?(Listing) && to_params == other.to_params
    end
    alias eql? ==

    def hash
      to_params.hash
    end
  end
end
