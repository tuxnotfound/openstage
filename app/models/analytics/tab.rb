module Analytics
  # The analytics page's tabs, in their order, each with its own address
  # (param, none for Overview): the numbers it lists, in its order, which
  # is not the pages' (Progress::Numbers::ALL); those with a tile, Site
  # visitors and Visitors drawing no line of their own; the ones its chart
  # opens on; whether its rows start with the builder's stage; whether it
  # lists every project or only those that count one of its numbers; which
  # lists sit under it; what a builder is asked to do while its chart is
  # empty (Progress::ChartStep); and whether Free opens it, with the line
  # its Go Pro view says where Free does not (pitch). Free reads its
  # commits, and the site visits of its one project (SiteVisits::Slot), on
  # the tabs it opens, never MRR nor Openstage's own numbers.
  class Tab
    FREE_NUMBERS = %w[commits visits site_visitors].freeze

    attr_reader :key, :label, :numbers, :tiles, :opens_on, :lists, :steps, :pitch

    def initialize(key:, label:, numbers:, opens_on:, tiles: numbers, stage: false, every_project: true, lists: nil, steps: [], free: true, pitch: nil)
      @key = key
      @label = label
      @numbers = numbers
      @tiles = tiles
      @opens_on = opens_on
      @stage = stage
      @every_project = every_project
      @lists = lists
      @steps = steps
      @free = free
      @pitch = pitch
    end

    ALL = [
      new(key: "overview", label: "Overview", numbers: %w[commits visits site_visitors mrr customers views visitors follows clicks],
          tiles: %w[commits visits mrr customers views follows clicks], opens_on: %w[commits visits mrr], stage: true, steps: %i[repos site stripe]),
      new(key: "commits", label: "Commits", numbers: %w[commits], opens_on: %w[commits], every_project: false, lists: :commits, steps: %i[repos]),
      new(key: "visits", label: "Site visits", numbers: %w[visits site_visitors], opens_on: %w[visits], lists: :websites, steps: %i[repos site]),
      new(key: "mrr", label: "MRR", numbers: %w[mrr customers], opens_on: %w[mrr], every_project: false, lists: :revenue, steps: %i[repos stripe], free: false,
          pitch: "Each project's MRR and paying customers, product by product, verified with Stripe."),
      new(key: "openstage", label: "Openstage views", numbers: %w[views visitors follows clicks], opens_on: %w[views], stage: true, lists: :pages, free: false,
          pitch: "Views of your stage and your project pages, where they came from, and the links followed.")
    ].freeze

    # The tab a param names; Overview for none, and for one it does not know.
    def self.find(key)
      ALL.find { |tab| tab.param == key.to_s } || ALL.first
    end

    # Its param in the page's address; nil for Overview, which leaves it out.
    def param
      key unless key == ALL.first.key
    end

    def opens?(user)
      @free || user.pro?
    end

    # The numbers it reads for a builder, by key, in its order.
    def numbers_for(user)
      user.pro? ? numbers : numbers & FREE_NUMBERS
    end

    # Whether its rows start with the builder's stage, whose numbers are Pro's.
    def stage?(user)
      @stage && user.pro?
    end

    # Whether it lists a project that counts none of its numbers, with no box.
    def every_project?
      @every_project
    end
  end
end
