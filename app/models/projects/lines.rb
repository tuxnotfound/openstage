module Projects
  # A project's numbers as the dashboard brings them in on a click, a line
  # each, in the order of analytics' tabs, site visits before MRR
  # (Progress::Numbers::ALL keeps its own order everywhere else). A line says
  # where its number stands (state):
  #   :switch   it counts, and a switch says whether visitors see it (on);
  #   :waiting  site visits: the script is on and no visit came yet;
  #   :set_up   it could count, and a step sets it up;
  #   :slot     Free counts another project's (SiteVisits::Slot, Revenue::Slot);
  #   :mine     MRR on Free: it counts, and only its builder sees it;
  #   :full     pinned: every colour is taken, and this project has none.
  # Site visitors and paying customers have a line once site visits and MRR
  # count. Past Projects::DashboardList::MANY projects a last line pins it
  # (pins: the full names of the pinned ones). A project off the stage keeps
  # its lines, their switches dead. A number built later is one more line.
  class Lines
    Line = Data.define(:key, :state, :on, :dead)

    attr_reader :repo

    def initialize(repo, pins: nil)
      @repo = repo
      @pins = pins
    end

    def all
      [ Line.new("commits", :switch, repo.picks?("commits"), off_stage?), *site, *revenue, pin ].compact
    end

    # Whether Stripe is connected with a key it takes, so setting MRR up
    # picks the project's products rather than connecting Stripe first.
    def stripe_ready?
      account = Revenue::Book.new(repo.user).account
      account.present? && account.refused_at.nil?
    end

    def pinned?
      @pins&.include?(repo.full_name) || false
    end

    private

    def site
      return [ line("visits", :slot) ] if SiteVisits::Slot.new(repo.user).instead_of(repo)
      return [ line("visits", :set_up) ] unless repo.site_host && repo.counts_site_visits?
      return [ line("visits", :waiting) ] unless repo.site_first_visit_at

      [ switch("visits"), Line.new("site_visitors", :switch, repo.picks?("site_visitors"), off_stage? || repo.hides_beside?("site_visitors")) ]
    end

    def revenue
      return [ line("mrr", :slot) ] if Revenue::Slot.new(repo.user).instead_of(repo)
      return [ line("mrr", :set_up) ] unless stripe_ready? && repo.revenue_products.exists?
      return [ line("mrr", :mine), line("customers", :mine) ] unless repo.user.pro?

      [ switch("mrr"), switch("customers") ]
    end

    def pin
      return if @pins.nil?

      full = !pinned? && @pins.size >= ProgressChart::Palette::SIZE
      Line.new("pin", full ? :full : :switch, pinned?, off_stage? || full)
    end

    def switch(key)
      Line.new(key, :switch, repo.picks?(key), off_stage?)
    end

    def line(key, state)
      Line.new(key, state, false, false)
    end

    def off_stage?
      !repo.included?
    end
  end
end
