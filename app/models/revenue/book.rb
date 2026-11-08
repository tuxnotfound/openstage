module Revenue
  # What a builder's Stripe account holds for their projects, as the pages read
  # it: the last day read, the first day each project had revenue, and its days
  # in one currency (Levels). Only products counted for a project read here, and
  # nothing while Stripe refuses the key, so no stale figure stands as verified.
  class Book
    def initialize(user)
      @user = user
    end

    def account
      return @account if defined?(@account)

      @account = @user.revenue_accounts.find_by(provider: "stripe")
    end

    def live?
      account.present? && account.refused_at.nil?
    end

    # The last day read, in the builder's zone; nil before the first read.
    def read_day
      account&.read_at&.in_time_zone(@user.zone)&.to_date
    end

    # { repo id => its first day with revenue }.
    def firsts
      @firsts ||= live? ? counted_days.group("revenue_products.github_repo_id").minimum(:day) : {}
    end

    # The projects with revenue.
    def repos
      @user.github_repos.where(id: firsts.keys).to_a
    end

    # { number's key => { repo's full name => its first day } }, of these
    # projects: MRR and paying customers begin together, at the first sale.
    def first_days(some = repos)
      days = some.filter_map { |repo| [ repo.full_name, firsts[repo.id] ] if firsts.key?(repo.id) }.to_h
      Progress::Numbers::REVENUE.index_with { days }
    end

    # Levels of these projects, from a day on; nil from for every day. With no
    # day since then, their revenue has ended: they stand at nothing, in the
    # currency it last was in.
    def levels(repos, from: nil)
      days = counted_days.where(revenue_products: { github_repo_id: repos.map(&:id) })
      rows = (from ? days.where(day: from..) : days).pluck("revenue_products.github_repo_id", :day, :currency, :mrr, :subscriptions).map do |repo_id, day, currency, mrr, subscriptions|
        Levels::Row.new(repo_id: repo_id, day: day, currency: currency, mrr: mrr, subscriptions: subscriptions)
      end
      Levels.new(rows, ended_in: (days.order(day: :desc).pick(:currency) if rows.empty?))
    end

    private

    def counted_days
      RevenueDay.joins(:revenue_product).where(revenue_products: { revenue_account_id: account.id }).where.not(revenue_products: { github_repo_id: nil })
    end
  end
end
