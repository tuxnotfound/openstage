module Progress
  # What the stage's list of projects shows (ListService): its order, the
  # name searched for, whether only live projects show, and which page of
  # them. Read from a page's or the API's params, so an address no one could
  # have meant (an unknown order, page 0) still opens a list. A link leaves
  # the defaults out of its address.
  class Listing
    # Latest commit first, the most commits over the cards' 52 weeks first,
    # or by name. The first is the default.
    SORTS = %w[latest commits name].freeze
    # Longer than any repo's name, which GitHub caps at 100.
    QUERY_LENGTH = 100
    # What a link or a form sends for the live projects alone.
    LIVE_VALUES = %w[1 true].freeze

    attr_reader :sort, :query, :live, :page

    def self.from(params)
      new(sort: params[:sort], query: params[:q], live: params[:live], page: params[:page])
    end

    def initialize(sort: nil, query: nil, live: nil, page: nil)
      @sort = sort.to_s.presence_in(SORTS) || SORTS.first
      @query = query.to_s.strip.first(QUERY_LENGTH)
      @live = LIVE_VALUES.include?(live.to_s)
      @page = [ page.to_i, 1 ].max
    end

    def to_params
      { sort: (sort unless sort == SORTS.first), q: query.presence, live: ("1" if live), page: (page if page > 1) }.compact
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
