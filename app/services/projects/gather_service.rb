module Projects
  # What a project's builder sees on its own view: its colour, its numbers over
  # the last 30 days, and where its site visits stand. Site visits are counted
  # (by the script, on its website), paused (the script on while Free counts
  # another project, SiteVisits::Slot), or off; a project without a website
  # has nowhere to count them.
  class GatherService < ApplicationService
    DAYS = 30

    attr_accessor :repo
    # project: its Progress::Projects entry, nil with nothing public yet;
    # last_site_visit: when the latest counted; site_state: :counting,
    # :paused, :off or :no_website; slot_project: the project that holds
    # Free's slot instead of this one, nil when this one can count.
    # revenue_account: the builder's Stripe account, nil until connected;
    # revenue_products: its products, listed; revenue_slot_project: as
    # slot_project, for MRR (Revenue::Slot); revenue_days: each product's
    # RevenueDays on the last day read, by product id.
    attr_reader :project, :commits, :last_commit, :site_visits, :site_visitors, :last_site_visit, :site_state, :slot_project,
                :revenue_account, :revenue_products, :revenue_slot_project, :revenue_days

    validates :repo, presence: true

    private

    def execute
      entries = user.entries.publicly_counted.without_tooling_noise
      @project = Progress::Projects.new(entries).find(repo.full_name)
      commits = entries.commits.where(repo_name: repo.full_name)
      @commits = commits.where(occurred_at: (today - (DAYS - 1)).in_time_zone(user.zone)..).count
      @last_commit = commits.maximum(:occurred_at)&.in_time_zone(user.zone)&.to_date
      @site_visits, @site_visitors = repo.site_visit_days.where(day: (today - (DAYS - 1))..today)
                                         .pick(Arel.sql("COALESCE(SUM(visits), 0)"), Arel.sql("COALESCE(SUM(visitors), 0)"))
      @last_site_visit = repo.site_visit_days.maximum(:updated_at)
      slot = SiteVisits::Slot.new(user)
      @slot_project = slot.instead_of(repo)
      @site_state = site_state_now(slot.state(repo))
      gather_revenue
    end

    def user
      repo.user
    end

    def today
      Time.current.in_time_zone(user.zone).to_date
    end

    # A paused project stays paused whatever its website; otherwise the
    # script has nowhere to count without one.
    def site_state_now(state)
      state != :paused && repo.site_host.nil? ? :no_website : state
    end

    def gather_revenue
      @revenue_account = user.revenue_accounts.find_by(provider: "stripe")
      @revenue_products = @revenue_account ? @revenue_account.revenue_products.listed.includes(:github_repo).to_a : []
      @revenue_slot_project = Revenue::Slot.new(user).instead_of(repo)
      read_day = @revenue_account&.read_at&.in_time_zone(user.zone)&.to_date
      @revenue_days = read_day ? RevenueDay.where(revenue_product_id: @revenue_products.map(&:id), day: read_day).group_by(&:revenue_product_id) : {}
    end
  end
end
